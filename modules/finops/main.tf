# FinOps guardrails: a single SNS topic fans budget threshold breaches and cost
# anomalies out to email. Everything runs in us-east-1 (aws.billing) because
# Budgets and Cost Explorer are only available there.

locals {
  # One notification per (threshold, type) so we alert on both spend-to-date and
  # forecasted spend.
  budget_notifications = flatten([
    for p in var.budget_thresholds_percent : [
      { type = "ACTUAL", threshold = p },
      { type = "FORECASTED", threshold = p },
    ]
  ])
}

resource "aws_sns_topic" "this" {
  provider = aws.billing
  name     = var.sns_topic_name

  # Server-side encryption with the AWS-managed SNS key (no key to manage).
  kms_master_key_id = "alias/aws/sns"

  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.notification_emails)

  provider  = aws.billing
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}

# Allow the AWS cost services to publish to the topic.
data "aws_iam_policy_document" "topic" {
  statement {
    sid       = "AllowCostServicesToPublish"
    effect    = "Allow"
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.this.arn]
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com", "costalerts.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  provider = aws.billing
  arn      = aws_sns_topic.this.arn
  policy   = data.aws_iam_policy_document.topic.json
}

resource "aws_budgets_budget" "monthly" {
  provider = aws.billing

  name         = "${var.sns_topic_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = var.budget_currency
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = { for n in local.budget_notifications : "${n.type}-${n.threshold}" => n }
    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value.threshold
      threshold_type            = "PERCENTAGE"
      notification_type         = notification.value.type
      subscriber_sns_topic_arns = [aws_sns_topic.this.arn]
    }
  }

  depends_on = [aws_sns_topic_policy.this]
}

resource "aws_ce_anomaly_monitor" "this" {
  count    = var.enable_anomaly_detection ? 1 : 0
  provider = aws.billing

  name              = "${var.sns_topic_name}-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = var.tags
}

resource "aws_ce_anomaly_subscription" "this" {
  count    = var.enable_anomaly_detection ? 1 : 0
  provider = aws.billing

  name             = "${var.sns_topic_name}-subscription"
  frequency        = "DAILY"
  monitor_arn_list = [aws_ce_anomaly_monitor.this[0].arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.this.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_amount)]
    }
  }

  depends_on = [aws_sns_topic_policy.this]
}
