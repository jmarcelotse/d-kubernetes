output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID da Subnet"
  value       = aws_subnet.main.id
}
