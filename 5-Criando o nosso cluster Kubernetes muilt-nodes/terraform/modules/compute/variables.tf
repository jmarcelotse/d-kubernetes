variable "cluster_name" {
  description = "Nome do cluster"
  type        = string
}

variable "subnet_id" {
  description = "ID da Subnet"
  type        = string
}

variable "security_group_id" {
  description = "ID do Security Group"
  type        = string
}

variable "master_count" {
  description = "Número de masters"
  type        = number
}

variable "worker_count" {
  description = "Número de workers"
  type        = number
}

variable "master_instance_type" {
  description = "Tipo de instância para masters"
  type        = string
}

variable "worker_instance_type" {
  description = "Tipo de instância para workers"
  type        = string
}

variable "public_key_path" {
  description = "Caminho para chave pública SSH"
  type        = string
}
