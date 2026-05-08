# =========================================================
# TERRAFORM + AWS EKS (LATEST STABLE PRODUCTION SETUP)
# File: main.tf
# =========================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# =========================================================
# AWS PROVIDER
# =========================================================

provider "aws" {
  region = "us-east-1"
}

# =========================================================
# VARIABLES
# =========================================================

variable "cluster_name" {
  type    = string
  default = "kscluster"
}

# =========================================================
# VPC
# =========================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "eks-vpc"

  cidr = "10.0.0.0/16"

  azs = [
    "us-east-1a",
    "us-east-1b"
  ]

  private_subnets = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]

  public_subnets = [
    "10.0.101.0/24",
    "10.0.102.0/24"
  ]

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# =========================================================
# EKS CLUSTER
# =========================================================

module "eks" {
  source  = "terraform-aws-modules/eks/aws"

  # Latest stable v20 release
  version = "20.31.6"

  # =========================================================
  # CLUSTER
  # =========================================================

  cluster_name    = var.cluster_name

  # Latest supported EKS version in stable provider/module
  cluster_version = "1.34"

  cluster_endpoint_public_access = true

  authentication_mode = "API_AND_CONFIG_MAP"

  enable_cluster_creator_admin_permissions = true

  enable_irsa = true

  vpc_id = module.vpc.vpc_id

  subnet_ids = module.vpc.private_subnets

  # =========================================================
  # EKS ADDONS (LATEST)
  # =========================================================

  cluster_addons = {

    coredns = {
      most_recent = true
    }

    kube-proxy = {
      most_recent = true
    }

    vpc-cni = {
      most_recent = true
    }

    eks-pod-identity-agent = {
      most_recent = true
    }

    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # =========================================================
  # MANAGED NODE GROUPS
  # =========================================================

  eks_managed_node_groups = {

    general = {

      # Latest Amazon Linux 2023 AMI
      ami_type = "AL2023_x86_64_STANDARD"

      # Latest recommended compute
      instance_types = ["t3.large"]

      capacity_type = "ON_DEMAND"

      min_size     = 2
      max_size     = 6
      desired_size = 3

      disk_size = 50

      labels = {
        role = "general"
      }

      update_config = {
        max_unavailable_percentage = 33
      }

      tags = {
        Name        = "eks-general-nodegroup"
        Environment = "production"
        Terraform   = "true"
      }
    }
  }

  # =========================================================
  # TAGS
  # =========================================================

  tags = {
    Environment = "production"
    Terraform   = "true"
  }
}

# =========================================================
# OUTPUTS
# =========================================================

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_version" {
  value = module.eks.cluster_version
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "region" {
  value = "us-east-1"
}
