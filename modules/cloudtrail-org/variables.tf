variable "organization_id" {
  description = "Organization id (o-xxxx); scopes the trail bucket policy to org accounts."
  type        = string
}

variable "management_account_id" {
  description = "Account id of the management account that owns the organization trail."
  type        = string
}

variable "log_archive_account_id" {
  description = "Account id of the log-archive account hosting the bucket and KMS key."
  type        = string
}

variable "region" {
  description = "Region in which the trail is created (used to build the trail ARN)."
  type        = string
  default     = "eu-west-3"
}

variable "bucket_name" {
  description = "Globally unique name for the central CloudTrail S3 bucket."
  type        = string
}

variable "trail_name" {
  description = "Name of the organization trail."
  type        = string
  default     = "org-trail"
}

variable "log_retention_days" {
  description = "Retention (days) for both the S3 lifecycle and the CloudWatch log group."
  type        = number
  default     = 365
}

variable "kms_key_deletion_window" {
  description = "Waiting period (days) before the trail KMS key is deleted."
  type        = number
  default     = 30
}

variable "enable_log_file_validation" {
  description = "Enable CloudTrail log file integrity validation."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to taggable resources."
  type        = map(string)
  default     = {}
}
