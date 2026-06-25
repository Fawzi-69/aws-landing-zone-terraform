variable "account_id" {
  description = "AWS account id of the workloads-prod account (from the global outputs)."
  type        = string
}

variable "region" {
  description = "Workload region."
  type        = string
  default     = "eu-west-3"
}

variable "env" {
  description = "Environment name (tag value)."
  type        = string
  default     = "prod"
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
  description = "Cross-account role assumed in the workloads account."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

variable "vpc_cidr" {
  description = "CIDR block for the environment VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread the VPC across."
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway. Defaults to false in production for per-AZ resilience."
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly cost budget for this environment."
  type        = number
  default     = 500
}

variable "notification_emails" {
  description = "Emails subscribed to this environment's cost alerts."
  type        = list(string)
  default     = []
}
