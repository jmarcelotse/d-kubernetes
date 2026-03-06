output "master_instance_ids" {
  description = "IDs das instâncias master"
  value       = aws_instance.masters[*].id
}

output "master_public_ips" {
  description = "IPs públicos dos masters"
  value       = aws_instance.masters[*].public_ip
}

output "master_private_ips" {
  description = "IPs privados dos masters"
  value       = aws_instance.masters[*].private_ip
}

output "worker_instance_ids" {
  description = "IDs das instâncias worker"
  value       = aws_instance.workers[*].id
}

output "worker_public_ips" {
  description = "IPs públicos dos workers"
  value       = aws_instance.workers[*].public_ip
}

output "worker_private_ips" {
  description = "IPs privados dos workers"
  value       = aws_instance.workers[*].private_ip
}

output "all_instances" {
  description = "Todas as instâncias"
  value = {
    masters = [
      for i, instance in aws_instance.masters : {
        name       = instance.tags["Name"]
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
      }
    ]
    workers = [
      for i, instance in aws_instance.workers : {
        name       = instance.tags["Name"]
        public_ip  = instance.public_ip
        private_ip = instance.private_ip
      }
    ]
  }
}
