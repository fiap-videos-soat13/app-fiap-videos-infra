variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

output "secret_arns" {
  value = { for key, secret in aws_secretsmanager_secret.app : key => secret.arn }
}

locals {
  secret_keys = toset([
    "jwt-secret",
    "database-url",
    "rabbitmq-url",
    "smtp-config",
  ])
}

resource "aws_secretsmanager_secret" "app" {
  for_each = local.secret_keys

  name = "${var.project_name}/${var.environment}/${each.key}"
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each = local.secret_keys

  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = "REPLACE_ME"
}
