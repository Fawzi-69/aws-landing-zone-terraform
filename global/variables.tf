variable "region" {
  description = "Primary region for organization resources."
  type        = string
  default     = "eu-west-3"
}

variable "project" {
  description = "Project tag value."
  type        = string
  default     = "aws-landing-zone"
}

variable "owner" {
  description = "Owner tag value."
  type        = string
  default     = "platform-team"
}

variable "member_account_access_role" {
  description = "Cross-account role assumed in member accounts (set at account creation)."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "account_emails" {
  description = "Root email for each member account (must be unique and deliverable)."
  type = object({
    log_archive     = string
    security        = string
    shared_services = string
    workloads_dev   = string
    workloads_prod  = string
  })
}

variable "cloudtrail_bucket_name" {
  description = "Globally unique name for the central CloudTrail bucket (in log-archive)."
  type        = string
}

variable "log_archive_account_id" {
  description = "Account id of the log-archive account, supplied after phase-1 account creation. Leave empty during phase 1."
  type        = string
  default     = ""
}

variable "security_account_id" {
  description = "Account id of the security account (delegated admin for detective controls). Leave empty during phase 1."
  type        = string
  default     = ""
}

variable "enable_cross_account_baseline" {
  description = "Phase 2 switch: provision cross-account resources (org CloudTrail, detective controls). Requires the *_account_id variables to be set."
  type        = bool
  default     = false
}

variable "region_lock_allowed_regions" {
  description = "Regions permitted by the region-lock SCP on workloads/infrastructure."
  type        = list(string)
  default     = ["eu-west-3", "eu-west-1"]
}

variable "github_org" {
  description = "GitHub organization owning the infrastructure repository."
  type        = string
}

variable "github_repo" {
  description = "Infrastructure repository name allowed to deploy via OIDC."
  type        = string
}

variable "org_budget_amount" {
  description = "Monthly cost budget for the whole organization (payer account)."
  type        = number
  default     = 1000
}

variable "finops_notification_emails" {
  description = "Emails subscribed to organization-level cost alerts."
  type        = list(string)
  default     = []
}
