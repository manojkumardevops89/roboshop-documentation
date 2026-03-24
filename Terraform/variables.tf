variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS Cluster name"
  default     = "roboshop-eks"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public subnet CIDRs"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private subnet CIDRs"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "AZs"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "node_instance_type" {
  description = "EKS node instance type"
  default     = "t3.medium"
}

variable "desired_capacity" {
  default = 2
}

variable "min_size" {
  default = 1
}

variable "max_size" {
  default = 3
}

variable "domain_name" {
  description = "Route53 domain"
  default     = "roboshop.yourdomain.com"
}
