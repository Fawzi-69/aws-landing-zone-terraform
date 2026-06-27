output "guardduty_detector_id" {
  description = "GuardDuty detector id in the security account (null when disabled)."
  value       = try(aws_guardduty_detector.this[0].id, null)
}

output "securityhub_admin_account_id" {
  description = "Security account id acting as Security Hub delegated admin (null when disabled)."
  value       = try(aws_securityhub_organization_admin_account.this[0].admin_account_id, null)
}

output "access_analyzer_arn" {
  description = "ARN of the organization Access Analyzer (null when disabled)."
  value       = try(aws_accessanalyzer_analyzer.org[0].arn, null)
}
