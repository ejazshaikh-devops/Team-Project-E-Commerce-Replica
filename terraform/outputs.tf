# ── Outputs — copy these into your K8s secrets / CI/CD ─────

output "region" {
  value = var.region
}

output "cluster_name" {
  description = "Run: aws eks update-kubeconfig --name <this> --region ap-south-1"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_registry" {
  description = "ECR registry URL prefix — use as IMAGE prefix in CI/CD"
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
}

output "ecr_repos" {
  description = "Full ECR URLs per service"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "rds_endpoint" {
  description = "Put this in K8s DB_HOST secret"
  value       = aws_db_instance.mariadb.address
  sensitive   = true
}

output "rds_port" {
  value = aws_db_instance.mariadb.port
}

output "rds_db_name" {
  value = aws_db_instance.mariadb.db_name
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "kubectl_config_cmd" {
  description = "Run this after terraform apply to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
