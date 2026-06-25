output "sns_topic_arn" {
  description = "ARN of the alerts SNS topic."
  value       = aws_sns_topic.this.arn
}

output "budget_id" {
  description = "Id of the monthly cost budget."
  value       = aws_budgets_budget.monthly.id
}

output "anomaly_monitor_arn" {
  description = "ARN of the cost anomaly monitor (null when disabled)."
  value       = try(aws_ce_anomaly_monitor.this[0].arn, null)
}
