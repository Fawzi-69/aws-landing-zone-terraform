variable "name" {
  description = "Name prefix for the VPC and its resources."
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR block of the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones to spread subnets across."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public tier (one per AZ)."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs for the private application tier (one per AZ)."
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "CIDRs for the private data tier (one per AZ)."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Provision NAT gateway(s) so the app tier can reach the internet outbound."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single shared NAT gateway (cheaper) instead of one per AZ."
  type        = bool
  default     = true
}

variable "data_tier_ingress_ports" {
  description = "TCP ports the data tier accepts from the application tier (e.g. database engines)."
  type        = list(number)
  default     = [5432, 3306, 6379, 1433, 27017]
}

variable "enable_flow_logs" {
  description = "Capture VPC flow logs to an encrypted CloudWatch log group."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Retention period (days) for the flow logs log group."
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
