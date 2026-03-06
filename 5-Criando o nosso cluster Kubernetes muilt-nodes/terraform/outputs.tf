output "vpc_id" {
  description = "ID da VPC"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "ID da Subnet"
  value       = module.network.subnet_id
}

output "security_group_id" {
  description = "ID do Security Group"
  value       = module.security.security_group_id
}

output "master_instance_ids" {
  description = "IDs das instâncias master"
  value       = module.compute.master_instance_ids
}

output "master_public_ips" {
  description = "IPs públicos dos masters"
  value       = module.compute.master_public_ips
}

output "master_private_ips" {
  description = "IPs privados dos masters"
  value       = module.compute.master_private_ips
}

output "worker_instance_ids" {
  description = "IDs das instâncias worker"
  value       = module.compute.worker_instance_ids
}

output "worker_public_ips" {
  description = "IPs públicos dos workers"
  value       = module.compute.worker_public_ips
}

output "worker_private_ips" {
  description = "IPs privados dos workers"
  value       = module.compute.worker_private_ips
}

output "ssh_command_master_1" {
  description = "Comando SSH para conectar no master-1"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${module.compute.master_public_ips[0]}"
}

output "all_instances" {
  description = "Informações de todas as instâncias"
  value       = module.compute.all_instances
}
