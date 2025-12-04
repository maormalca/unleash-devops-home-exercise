# ==============================================================================
# Terraform Variables
# ==============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-north-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "unleash-exercise-cluster"
}

variable "s3_bucket_name" {
  description = "S3 bucket name (must be globally unique)"
  type        = string
  default     = "unleash-exercise-bucket-12345"
}

variable "ecr_repository_name" {
  description = "ECR repository name for Docker images"
  type        = string
  default     = "unleash-exercise-repo"
}
