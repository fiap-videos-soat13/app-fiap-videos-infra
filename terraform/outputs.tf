output "aws_region" {
  value = var.aws_region
}

output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
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

output "configure_kubectl" {
  description = "Run this command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoint" {
  value     = module.rds.endpoint
  sensitive = true
}

output "rds_username" {
  value = module.rds.username
}

output "rds_password" {
  value     = module.rds.password
  sensitive = true
}

output "rds_init_sql" {
  description = "Run once against RDS (from a pod in the VPC) to create per-service databases"
  value       = local.rds_init_sql
}

output "video_bucket_name" {
  value = module.s3.bucket_name
}

output "secrets_manager_arns" {
  value     = module.secrets.secret_arns
  sensitive = true
}

output "secrets_manager_names" {
  value = module.secrets.secret_names
}

output "irsa_s3_role_arns" {
  description = "Annotate Kubernetes service accounts with eks.amazonaws.com/role-arn"
  value       = module.irsa.s3_access_role_arns
}

output "eso_irsa_role_arn" {
  description = "Annotate the external-secrets service account in namespace external-secrets"
  value       = module.eso_irsa.role_arn
}

output "kustomize_replacements" {
  description = "Values to patch in k8s/overlays/staging before kubectl apply"
  value = {
    aws_account_id     = data.aws_caller_identity.current.account_id
    aws_region         = var.aws_region
    s3_bucket          = module.s3.bucket_name
    api_irsa_arn       = module.irsa.s3_access_role_arns.api
    processor_irsa_arn = module.irsa.s3_access_role_arns.processor
    eso_irsa_arn       = module.eso_irsa.role_arn
  }
}
