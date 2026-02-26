output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = values(aws_subnet.private)[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = values(aws_subnet.public)[*].id
}

output "private_route_table_id" {
  description = "Private route table ID."
  value       = aws_route_table.private.id
}

output "lambda_sg_id" {
  description = "Lambda security group ID."
  value       = aws_security_group.lambda_sg.id
}
