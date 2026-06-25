output "trail_arn" {
  description = "ARN of the organization CloudTrail."
  value       = aws_cloudtrail.org.arn
}

output "bucket_name" {
  description = "Name of the central CloudTrail bucket."
  value       = aws_s3_bucket.trail.id
}

output "bucket_arn" {
  description = "ARN of the central CloudTrail bucket."
  value       = aws_s3_bucket.trail.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting the trail."
  value       = aws_kms_key.trail.arn
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group receiving trail events."
  value       = aws_cloudwatch_log_group.trail.arn
}
