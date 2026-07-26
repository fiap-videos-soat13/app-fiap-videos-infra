output "aws_region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}

output "video_bucket_name" {
  value = module.s3.bucket_name
}

output "secrets_manager_arns" {
  value     = module.secrets.secret_arns
  sensitive = true
}

output "irsa_s3_role_arns" {
  description = "Annotate Kubernetes service accounts with eks.amazonaws.com/role-arn"
  value       = module.irsa.s3_access_role_arns
}
