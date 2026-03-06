variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nome do cluster Kubernetes"
  type        = string
  default     = "k8s-cluster"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR da Subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "master_count" {
  description = "Número de nós master"
  type        = number
  default     = 2
}

variable "worker_count" {
  description = "Número de nós worker"
  type        = number
  default     = 3
}

variable "master_instance_type" {
  description = "Tipo de instância para masters"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "Tipo de instância para workers"
  type        = string
  default     = "t3.medium"
}

variable "public_key_path" {
  description = "Caminho para chave pública SSH"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}
