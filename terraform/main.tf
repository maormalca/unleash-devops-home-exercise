terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name  = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id          = data.aws_vpc.default.id
  subnet_ids      = data.aws_subnets.default.ids

  cluster_endpoint_public_access = true

  enable_irsa = true

  # Grant cluster access to IAM users
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    admin = {
      principal_arn = "arn:aws:iam::532150070616:user/maor.malca"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = 2
      desired_size = 2

      instance_types = ["t3.medium"]
    }
  }
}

# Application dependencies
resource "aws_s3_bucket" "app_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}

# IAM Policy for S3 Access
data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:HeadObject"
    ]
    resources = [
      aws_s3_bucket.app_bucket.arn,
      "${aws_s3_bucket.app_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_policy" {
  name  = "${var.cluster_name}-s3-access"
  policy = data.aws_iam_policy_document.s3_policy.json
}

# IRSA: Create an IAM Role for the Kubernetes Service Account (app-sa)
module "irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-app-role"

  role_policy_arns = {
    s3_policy = aws_iam_policy.s3_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn           = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:app-sa"]
    }
  }
}