output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "vllm_irsa_role_arn" {
  value = module.vllm_irsa_role.iam_role_arn
}

output "lb_controller_irsa_role_arn" {
  value = module.lb_controller_irsa_role.iam_role_arn
}

output "kms_key_arn" {
  value = aws_kms_key.eks_secrets.arn
}
