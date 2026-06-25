output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state (use as backend `bucket`)."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = aws_s3_bucket.state.arn
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking (use as backend `dynamodb_table`)."
  value       = aws_dynamodb_table.lock.name
}

output "kms_key_arn" {
  description = "ARN of the KMS key encrypting state (use as backend `kms_key_id`)."
  value       = aws_kms_key.state.arn
}

output "region" {
  description = "Region of the backend resources (use as backend `region`)."
  value       = var.region
}
