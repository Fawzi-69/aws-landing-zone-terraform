output "vpc_id" {
  description = "Id of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Primary CIDR of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Ids of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "Ids of the private application subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "Ids of the private data subnets."
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "Ids of the NAT gateways (empty when NAT is disabled)."
  value       = aws_nat_gateway.this[*].id
}

output "default_security_group_id" {
  description = "Id of the (locked-down) default security group."
  value       = aws_default_security_group.this.id
}

output "flow_log_id" {
  description = "Id of the VPC flow log (null when disabled)."
  value       = try(aws_flow_log.this[0].id, null)
}
