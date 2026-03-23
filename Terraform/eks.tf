module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "roboshop"
  subnet_ids      = var.subnet_ids
  cluster_version = "1.29"
}
