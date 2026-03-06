variable "cluster_name" {
  description = "Nome do cluster"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR da Subnet"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}
