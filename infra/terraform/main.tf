locals {
  azs              = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  private_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]
  create_route53   = var.route53_zone_name != "" && var.api_hostname != ""
  enable_s3_access = var.vllm_model_s3_bucket_arn != ""
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.name}-eks-secrets"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.10"

  name = "${var.name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway = true
  single_nat_gateway = false

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = "${var.name}-eks"
  }

  tags = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.30"

  cluster_name    = "${var.name}-eks"
  cluster_version = var.cluster_version

  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  cluster_encryption_config = {
    resources        = ["secrets"]
    provider_key_arn = aws_kms_key.eks_secrets.arn
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    ami_type                   = "AL2023_x86_64_STANDARD"
    attach_cluster_primary_security_group = true
    disk_size                  = 100
    iam_role_additional_policies = {
      AmazonSSMManagedInstanceCore = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
      CloudWatchAgentServerPolicy  = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
      AmazonEC2ContainerRegistryReadOnly = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    }
  }

  eks_managed_node_groups = {
    cpu = {
      instance_types = var.cpu_node_instance_types
      desired_size   = var.cpu_desired_size
      min_size       = var.cpu_min_size
      max_size       = var.cpu_max_size

      labels = {
        nodepool = "cpu"
      }
    }

    gpu = {
      ami_type       = "AL2023_x86_64_NVIDIA"
      instance_types = var.gpu_node_instance_types
      desired_size   = var.gpu_desired_size
      min_size       = var.gpu_min_size
      max_size       = var.gpu_max_size

      labels = {
        workload = "inference-gpu"
      }

      taints = {
        gpu = {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  tags = merge(var.tags, {
    "karpenter.sh/discovery" = "${var.name}-eks"
  })
}

resource "aws_iam_policy" "vllm_s3" {
  count       = local.enable_s3_access ? 1 : 0
  name        = "${var.name}-vllm-s3-read"
  description = "Read-only model access for vLLM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.vllm_model_s3_bucket_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${var.vllm_model_s3_bucket_arn}/*"]
      }
    ]
  })
}

module "vllm_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name = "${var.name}-vllm-irsa"

  role_policy_arns = merge(
    {
      cloudwatch = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
    },
    local.enable_s3_access ? { s3 = aws_iam_policy.vllm_s3[0].arn } : {}
  )

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${var.llm_namespace}:${var.llm_service_account_name}"]
    }
  }

  tags = var.tags
}

module "lb_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.47"

  role_name                              = "${var.name}-aws-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

data "aws_route53_zone" "selected" {
  count        = local.create_route53 ? 1 : 0
  name         = var.route53_zone_name
  private_zone = false
}

resource "aws_route53_record" "llm_api" {
  count   = local.create_route53 ? 1 : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.api_hostname
  type    = "CNAME"
  ttl     = 60
  records = ["pending-alb-dns.apply-k8s-first.example.com"]
}
