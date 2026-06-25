variable "region" {
  description = "AWS region hosting the remote state backend."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Project tag applied to every resource."
  type        = string
  default     = "aws-landing-zone"
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
  default     = "platform-team"
}

variable "state_bucket_name" {
  description = "Globally unique name for the S3 bucket that stores Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  type        = string
  default     = "terraform-state-lock"
}

variable "noncurrent_version_retention_days" {
  description = "Days to keep noncurrent state object versions before expiry."
  type        = number
  default     = 90
}
