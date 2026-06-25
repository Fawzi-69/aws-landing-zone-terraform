variable "permission_sets" {
  description = <<-EOT
    Permission sets keyed by name. `managed_policy_arns` attaches AWS-managed
    policies, `customer_managed_policy_names` references policies that already
    exist in each target account, and `inline_policy` is an optional JSON
    document for fine-grained, least-privilege grants.
  EOT
  type = map(object({
    description                   = string
    session_duration              = optional(string, "PT1H")
    managed_policy_arns           = optional(list(string), [])
    customer_managed_policy_names = optional(list(string), [])
    inline_policy                 = optional(string, "")
  }))
  default = {}
}

variable "groups" {
  description = "Identity Store groups to create."
  type        = list(string)
  default     = []
}

variable "assignments" {
  description = "Group-to-account permission-set assignments."
  type = list(object({
    group_name          = string
    account_name        = string
    permission_set_name = string
  }))
  default = []
}

variable "account_ids" {
  description = "Map of logical account name to AWS account id (from the organization module)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags applied to permission sets."
  type        = map(string)
  default     = {}
}
