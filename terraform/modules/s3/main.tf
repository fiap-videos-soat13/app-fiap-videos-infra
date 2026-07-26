variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

output "bucket_name" {
  value = aws_s3_bucket.videos.id
}

output "bucket_arn" {
  value = aws_s3_bucket.videos.arn
}

resource "aws_s3_bucket" "videos" {
  bucket = "${var.project_name}-${var.environment}-videos"
}

resource "aws_s3_bucket_versioning" "videos" {
  bucket = aws_s3_bucket.videos.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "videos" {
  bucket = aws_s3_bucket.videos.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "videos" {
  bucket = aws_s3_bucket.videos.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
