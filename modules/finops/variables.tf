variable "sns_topic_name" {
  description = "Name of the SNS topic carrying budget and anomaly alerts."
  type        = string
}

variable "notification_emails" {
  description = "Email addresses subscribed to the alert topic."
  type        = list(string)
  default     = []
}

variable "monthly_budget_amount" {
  description = "Monthly cost budget limit."
  type        = number
}

variable "budget_currency" {
  description = "Budget currency code. Must match the account's billing currency (AWS default is USD)."
  type        = string
  default     = "USD"
}

variable "budget_thresholds_percent" {
  description = "Percentages of the budget at which to alert (both actual and forecasted)."
  type        = list(number)
  default     = [80, 100, 120]
}

variable "enable_anomaly_detection" {
  description = "Enable Cost Anomaly Detection."
  type        = bool
  default     = true
}

variable "anomaly_threshold_amount" {
  description = "Minimum absolute cost impact (in budget currency) before an anomaly alert fires."
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags applied to taggable resources."
  type        = map(string)
  default     = {}
}
