data "aws_caller_identity" "current" {}

resource "random_password" "jwt" {
  length  = 32
  special = false
}

locals {
  rds_endpoint = module.rds.endpoint
  rds_port     = module.rds.port
  rds_username = module.rds.username
  rds_password = module.rds.password

  database_urls = {
    api-database-url       = "postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}:${local.rds_port}/fiap_videos_api"
    processor-database-url = "postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}:${local.rds_port}/fiap_videos_processor"
    notifier-database-url  = "postgresql://${local.rds_username}:${local.rds_password}@${local.rds_endpoint}:${local.rds_port}/fiap_videos_notifier"
  }

  secret_values = merge(local.database_urls, {
    jwt-secret   = random_password.jwt.result
    rabbitmq-url = var.in_cluster_rabbitmq_url
    redis-url    = var.in_cluster_redis_url
    smtp-config = jsonencode({
      host = "mailhog"
      port = "1025"
      from = "noreply@fiap-videos.local"
    })
  })

  rds_init_sql = <<-SQL
    CREATE DATABASE fiap_videos_api;
    CREATE DATABASE fiap_videos_processor;
    CREATE DATABASE fiap_videos_notifier;

    \\c fiap_videos_api
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    \\c fiap_videos_processor
    CREATE EXTENSION IF NOT EXISTS pgcrypto;

    \\c fiap_videos_notifier
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
  SQL
}

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
  db_instance_class       = var.db_instance_class
}

module "secrets" {
  source = "./modules/secrets"

  project_name  = var.project_name
  environment   = var.environment
  secret_values = local.secret_values

  depends_on = [module.rds]
}

module "eks" {
  source = "./modules/eks"

  project_name         = var.project_name
  environment          = var.environment
  cluster_version      = var.eks_cluster_version
  node_instance_types  = var.eks_node_instance_types
  node_desired_size    = var.eks_node_desired_size
  node_min_size        = var.eks_node_min_size
  node_max_size        = var.eks_node_max_size
  video_bucket_arn     = module.s3.bucket_arn
  secrets_manager_arns = values(module.secrets.secret_arns)

  depends_on = [module.secrets]
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

module "eso_irsa" {
  source = "./modules/eso-irsa"

  project_name         = var.project_name
  environment          = var.environment
  oidc_provider_arn    = module.eks.oidc_provider_arn
  oidc_provider_url    = module.eks.oidc_provider_url
  secrets_manager_arns = values(module.secrets.secret_arns)

  depends_on = [module.eks, module.secrets]
}
