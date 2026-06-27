output "organization_id" {
  description = "The organization id."
  value       = module.organization.organization_id
}

output "ou_ids" {
  description = "Map of logical OU name to id."
  value       = module.organization.ou_ids
}

output "account_ids" {
  description = "Map of logical account name to account id."
  value       = module.organization.account_ids
}

output "cloudtrail_bucket_arn" {
  description = "ARN of the central CloudTrail bucket (null until phase 2)."
  value       = try(module.cloudtrail[0].bucket_arn, null)
}

output "identity_center_permission_set_arns" {
  description = "Map of permission set name to ARN."
  value       = module.identity_center.permission_set_arns
}

output "github_plan_role_arn" {
  description = "ARN of the read-only GitHub Actions plan role (CI secret AWS_PLAN_ROLE_ARN)."
  value       = module.github_oidc_plan.role_arn
}

output "github_apply_role_arn" {
  description = "ARN of the privileged GitHub Actions apply role (CI secret AWS_APPLY_ROLE_ARN)."
  value       = module.github_oidc_apply.role_arn
}

output "finops_sns_topic_arn" {
  description = "ARN of the organization FinOps alert topic."
  value       = module.finops_org.sns_topic_arn
}
