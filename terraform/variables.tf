variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  default     = "staging"
}

variable "project_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "fiap-videos"
}

variable "eks_cluster_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "db_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "fiap"
}

variable "db_allocated_storage_gb" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "ecr_repository_names" {
  description = "ECR repositories for application images"
  type        = list(string)
  default = [
    "fiap-videos-api",
    "fiap-videos-processor",
    "fiap-videos-notifier",
  ]
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for IRSA service account subjects"
  type        = string
  default     = "fiap-videos"
}

variable "k8s_service_account_prefix" {
  description = "Must match Kustomize namePrefix on ServiceAccounts (staging- or production-)"
  type        = string
  default     = "staging-"
}
