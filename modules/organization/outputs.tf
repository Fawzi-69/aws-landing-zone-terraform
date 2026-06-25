output "organization_id" {
  description = "The organization identifier (o-xxxxxxxxxx)."
  value       = aws_organizations_organization.this.id
}

output "organization_arn" {
  description = "ARN of the organization."
  value       = aws_organizations_organization.this.arn
}

output "root_id" {
  description = "The organization root identifier (r-xxxx)."
  value       = aws_organizations_organization.this.roots[0].id
}

output "ou_ids" {
  description = "Map of logical OU name to OU id."
  value       = local.ou_ids
}

output "account_ids" {
  description = "Map of logical account name to AWS account id."
  value       = { for k, a in aws_organizations_account.this : k => a.id }
}

output "account_arns" {
  description = "Map of logical account name to account ARN."
  value       = { for k, a in aws_organizations_account.this : k => a.arn }
}
