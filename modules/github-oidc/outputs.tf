output "role_arn" {
  description = "ARN of the deploy role assumed by GitHub Actions."
  value       = aws_iam_role.deploy.arn
}

output "role_name" {
  description = "Name of the deploy role."
  value       = aws_iam_role.deploy.name
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider in use."
  value       = local.provider_arn
}
