# ── EKS Cluster ────────────────────────────────────────────
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.4"

  cluster_name    = "${var.project}-cluster"
  cluster_version = "1.36"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Allow public API endpoint (for kubectl from your machine)
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  # Enable IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Cluster addons
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
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Managed node group
  eks_managed_node_groups = {
    general = {
      name = "${var.project}-nodes"

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"

      min_size     = var.node_min
      max_size     = var.node_max
      desired_size = var.node_desired

      disk_size = 20

      labels = {
        role = "general"
      }

      # Allow nodes to reach RDS
      vpc_security_group_ids = [aws_security_group.eks_nodes_extra.id]
    }
  }

  # Grant your IAM user cluster-admin
  enable_cluster_creator_admin_permissions = true
}

# ── Extra SG for EKS nodes (to allow RDS access) ───────────
resource "aws_security_group" "eks_nodes_extra" {
  name        = "${var.project}-eks-nodes-extra"
  description = "Extra rules for EKS nodes"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}
