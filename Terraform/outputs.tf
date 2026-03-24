output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public Subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private Subnets"
  value       = module.vpc.private_subnets
}

output "eks_cluster_name" {
  description = "EKS Cluster Name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_security_group_id" {
  description = "Cluster security group"
  value       = module.eks.cluster_security_group_id
}

output "node_group_arn" {
  description = "Node group ARN"
  value       = module.eks.eks_managed_node_groups
}

output "route53_record" {
  description = "Application DNS"
  value       = var.domain_name
}
