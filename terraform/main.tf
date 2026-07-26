module "ecr" {
  source = "./modules/ecr"

  repository_names = var.ecr_repository_names
}

module "s3" {
  source = "./modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

module "rds" {
  source = "./modules/rds"

  project_name            = var.project_name
  environment             = var.environment
  db_username             = var.db_username
  db_allocated_storage_gb = var.db_allocated_storage_gb
}

module "secrets" {
  source = "./modules/secrets"

  project_name = var.project_name
  environment  = var.environment
}

module "eks" {
  source = "./modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_version      = var.eks_cluster_version
  node_instance_types  = var.eks_node_instance_types
  node_desired_size    = var.eks_node_desired_size
  video_bucket_arn     = module.s3.bucket_arn
  secrets_manager_arns = values(module.secrets.secret_arns)
}

module "irsa" {
  source = "./modules/irsa"

  project_name           = var.project_name
  environment            = var.environment
  oidc_provider_arn      = module.eks.oidc_provider_arn
  oidc_provider_url      = module.eks.oidc_provider_url
  video_bucket_arn       = module.s3.bucket_arn
  k8s_namespace          = var.k8s_namespace
  service_account_prefix = var.k8s_service_account_prefix

  depends_on = [module.eks]
}
