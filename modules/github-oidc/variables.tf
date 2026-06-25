variable "github_org" {
  description = "GitHub organization (or user) owning the repository."
  type        = string
}

variable "github_repo" {
  description = "Repository name allowed to assume the deploy role."
  type        = string
}

variable "allowed_branches" {
  description = "Branches whose workflow runs may assume the role."
  type        = list(string)
  default     = ["main"]
}

variable "allow_pull_requests" {
  description = "Also allow pull_request workflow runs (typically read-only plan)."
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
  default     = "github-actions-deploy"
}

variable "permissions_policy_arns" {
  description = "Managed policy ARNs attached to the deploy role."
  type        = list(string)
  default     = []
}

variable "inline_policy" {
  description = "Optional inline JSON policy granting the role its permissions."
  type        = string
  default     = ""
}

variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false to reuse an existing one in the account."
  type        = bool
  default     = true
}

variable "max_session_duration" {
  description = "Maximum session duration (seconds) for the deploy role."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags applied to the role and provider."
  type        = map(string)
  default     = {}
}
