variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "secret_values" {
  type      = map(string)
  sensitive = true
}

output "secret_arns" {
  value = { for key, secret in aws_secretsmanager_secret.app : key => secret.arn }
}

output "secret_names" {
  value = { for key, secret in aws_secretsmanager_secret.app : key => secret.name }
}

locals {
  secret_keys = toset([
    "jwt-secret",
    "api-database-url",
    "processor-database-url",
    "notifier-database-url",
    "rabbitmq-url",
    "redis-url",
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
  secret_string = var.secret_values[each.key]
}
