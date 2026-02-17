variable "name" {
  description = "Cluster/workload prefix"
  type        = string
  default     = "llm"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of AZs to use (2-3 recommended)"
  type        = number
  default     = 3
}

variable "cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.31"
}

variable "cluster_endpoint_public_access" {
  description = "Whether EKS API endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Allowed CIDRs if public endpoint is enabled"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cpu_node_instance_types" {
  description = "CPU node group instance types"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "gpu_node_instance_types" {
  description = "GPU node group instance types"
  type        = list(string)
  default     = ["g5.2xlarge"]
}

variable "cpu_desired_size" {
  type    = number
  default = 2
}

variable "cpu_min_size" {
  type    = number
  default = 2
}

variable "cpu_max_size" {
  type    = number
  default = 6
}

variable "gpu_desired_size" {
  type    = number
  default = 1
}

variable "gpu_min_size" {
  type    = number
  default = 0
}

variable "gpu_max_size" {
  type    = number
  default = 4
}

variable "llm_namespace" {
  description = "Namespace for LLM workloads"
  type        = string
  default     = "llm"
}

variable "llm_service_account_name" {
  description = "Service account for vLLM"
  type        = string
  default     = "vllm"
}

variable "vllm_model_s3_bucket_arn" {
  description = "Optional model bucket ARN for read-only access"
  type        = string
  default     = ""
}

variable "route53_zone_name" {
  description = "Route53 hosted zone name (without trailing dot), e.g. yourdomain.com"
  type        = string
  default     = ""
}

variable "api_hostname" {
  description = "DNS host for endpoint, e.g. llm.api.yourdomain.com"
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM cert ARN for HTTPS ingress"
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Common tags"
  default = {
    project = "llm-eks"
  }
}
