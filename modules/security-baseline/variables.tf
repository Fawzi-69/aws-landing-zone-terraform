variable "enable_guardduty" {
  description = "Enable GuardDuty org-wide with the security account as delegated admin."
  type        = bool
  default     = true
}

variable "enable_securityhub" {
  description = "Enable Security Hub org-wide with the security account as delegated admin."
  type        = bool
  default     = true
}

variable "enable_access_analyzer" {
  description = "Create an organization-wide IAM Access Analyzer."
  type        = bool
  default     = true
}

variable "auto_enable_new_accounts" {
  description = "Automatically enroll new member accounts into the detective controls."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to taggable resources."
  type        = map(string)
  default     = {}
}
