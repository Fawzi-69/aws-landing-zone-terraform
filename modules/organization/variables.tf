variable "aws_service_access_principals" {
  description = "AWS service principals granted trusted access within the organization."
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "guardduty.amazonaws.com",
    "config.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "ram.amazonaws.com",
    "account.amazonaws.com",
  ]
}

variable "enabled_policy_types" {
  description = "Organization policy types to enable on the root."
  type        = list(string)
  default     = ["SERVICE_CONTROL_POLICY", "TAG_POLICY"]
}

variable "member_accounts" {
  description = <<-EOT
    Member accounts to create, keyed by a logical name. `ou_key` must match one
    of the created OUs: security, infrastructure, workloads_dev, workloads_prod,
    sandbox, suspended.
  EOT
  type = map(object({
    name              = string
    email             = string
    ou_key            = string
    close_on_deletion = optional(bool, false)
  }))

  validation {
    condition = alltrue([
      for a in values(var.member_accounts) :
      contains(["security", "infrastructure", "workloads_dev", "workloads_prod", "sandbox", "suspended"], a.ou_key)
    ])
    error_message = "Each account ou_key must be one of: security, infrastructure, workloads_dev, workloads_prod, sandbox, suspended."
  }
}

variable "tags" {
  description = "Additional tags applied to taggable organization resources."
  type        = map(string)
  default     = {}
}
