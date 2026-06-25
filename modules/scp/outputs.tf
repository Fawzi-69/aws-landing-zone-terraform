output "policy_id" {
  description = "Id of the created Service Control Policy."
  value       = aws_organizations_policy.this.id
}

output "policy_arn" {
  description = "ARN of the created Service Control Policy."
  value       = aws_organizations_policy.this.arn
}

output "attachment_target_ids" {
  description = "Target ids the policy is attached to."
  value       = [for a in aws_organizations_policy_attachment.this : a.target_id]
}
