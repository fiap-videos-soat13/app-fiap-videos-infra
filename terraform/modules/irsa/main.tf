variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "oidc_provider_arn" {
  type = string
}

variable "oidc_provider_url" {
  type = string
}

variable "video_bucket_arn" {
  type = string
}

variable "k8s_namespace" {
  type    = string
  default = "fiap-videos"
}

variable "service_account_prefix" {
  type        = string
  default     = ""
  description = "Kustomize namePrefix on ServiceAccounts (e.g. staging- → staging-fiap-videos-api)"
}

output "s3_access_role_arns" {
  value = { for name, role in aws_iam_role.video_storage : name => role.arn }
}

locals {
  oidc_host = replace(var.oidc_provider_url, "https://", "")

  services = {
    api = {
      service_account = "fiap-videos-api"
    }
    processor = {
      service_account = "fiap-videos-processor"
    }
  }
}

resource "aws_iam_role" "video_storage" {
  for_each = local.services

  name = "${var.project_name}-${var.environment}-${each.key}-s3"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${local.oidc_host}:aud" = "sts.amazonaws.com"
          "${local.oidc_host}:sub" = "system:serviceaccount:${var.k8s_namespace}:${var.service_account_prefix}${each.value.service_account}"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "video_storage" {
  for_each = aws_iam_role.video_storage

  name = "s3-video-access"
  role = each.value.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        var.video_bucket_arn,
        "${var.video_bucket_arn}/*",
      ]
    }]
  })
}
