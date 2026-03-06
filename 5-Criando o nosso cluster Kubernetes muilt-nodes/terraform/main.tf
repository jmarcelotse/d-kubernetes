terraform {
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

# Módulo de Rede
module "network" {
  source = "./modules/network"

  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
  subnet_cidr  = var.subnet_cidr
  aws_region   = var.aws_region
}

# Módulo de Segurança
module "security" {
  source = "./modules/security"

  cluster_name = var.cluster_name
  vpc_id       = module.network.vpc_id
}

# Módulo de Compute
module "compute" {
  source = "./modules/compute"

  cluster_name          = var.cluster_name
  subnet_id             = module.network.subnet_id
  security_group_id     = module.security.security_group_id
  master_count          = var.master_count
  worker_count          = var.worker_count
  master_instance_type  = var.master_instance_type
  worker_instance_type  = var.worker_instance_type
  public_key_path       = var.public_key_path
}
