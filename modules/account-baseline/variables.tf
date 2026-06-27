variable "enable_ebs_encryption_by_default" {
  description = "Turn on EBS encryption by default in the account/region."
  type        = bool
  default     = true
}

variable "enable_s3_account_public_access_block" {
  description = "Apply the account-wide S3 public access block."
  type        = bool
  default     = true
}

variable "enable_password_policy" {
  description = "Manage the IAM account password policy."
  type        = bool
  default     = true
}

variable "minimum_password_length" {
  description = "Minimum IAM user password length."
  type        = number
  default     = 14
}

variable "password_reuse_prevention" {
  description = "Number of previous passwords IAM users cannot reuse."
  type        = number
  default     = 24
}

variable "max_password_age" {
  description = "Maximum IAM user password age in days."
  type        = number
  default     = 90
}
