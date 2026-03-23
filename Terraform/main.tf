provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "./vpc"
}

module "eks" {
  source          = "./eks"
  cluster_name    = "roboshop-eks"
  subnet_ids      = module.vpc.private_subnets
}
