output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.app_bucket.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "irsa_role_arn" {
  description = "IAM role ARN for IRSA (annotated on ServiceAccount)"
  value       = module.irsa.iam_role_arn
}
