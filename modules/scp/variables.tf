variable "name" {
  description = "Name of the Service Control Policy."
  type        = string
}

variable "description" {
  description = "Human-readable description of the policy intent."
  type        = string
  default     = "Managed by Terraform"
}

variable "target_ids" {
  description = "OU and/or account ids the policy is attached to."
  type        = list(string)
  default     = []
}

variable "deny_leave_organization" {
  description = "Deny member accounts the ability to leave the organization."
  type        = bool
  default     = true
}

variable "deny_disable_cloudtrail" {
  description = "Deny stopping, deleting or tampering with CloudTrail trails."
  type        = bool
  default     = true
}

variable "deny_disable_guardduty" {
  description = "Deny disabling or deleting GuardDuty detectors."
  type        = bool
  default     = true
}

variable "require_imdsv2" {
  description = "Deny launching EC2 instances that do not enforce IMDSv2."
  type        = bool
  default     = true
}

variable "deny_root_user" {
  description = "Deny all actions performed by the account root user."
  type        = bool
  default     = true
}

variable "region_lock" {
  description = "Deny actions outside the allowed regions (global services excepted)."
  type        = bool
  default     = false
}

variable "allowed_regions" {
  description = "Regions permitted when region_lock is enabled."
  type        = list(string)
  default     = ["eu-west-3", "eu-west-1"]
}

variable "region_lock_global_services" {
  description = "Service action prefixes exempt from region locking (global endpoints)."
  type        = list(string)
  default = [
    "a4b:*",
    "account:*",
    "aws-marketplace:*",
    "aws-portal:*",
    "budgets:*",
    "ce:*",
    "cloudfront:*",
    "globalaccelerator:*",
    "health:*",
    "iam:*",
    "kms:*",
    "organizations:*",
    "route53:*",
    "shield:*",
    "support:*",
    "sts:*",
    "waf:*",
    "wafv2:*",
    "waf-regional:*",
  ]
}

variable "additional_statements" {
  description = "Extra SCP statements (raw objects) appended to the policy."
  type        = list(any)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy."
  type        = map(string)
  default     = {}
}
