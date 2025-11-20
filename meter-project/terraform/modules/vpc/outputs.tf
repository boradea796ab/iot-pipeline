output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}

output "public_subnet_ids" {
  value = local.create_public_resources ? values(aws_subnet.public)[*].id : []
}

output "private_route_table_id" {
  value = aws_route_table.private.id
}

output "public_route_table_id" {
  value = local.create_public_resources ? aws_route_table.public[0].id : ""
}
