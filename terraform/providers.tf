provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "fiap-videos"
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
