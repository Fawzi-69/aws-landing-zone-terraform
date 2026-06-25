# Per-account baseline for the workloads-prod account: account-level hardening,
# a segmented VPC, and environment cost guardrails.

# --- Account hardening --------------------------------------------------------

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}

# --- Network ------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name       = "${var.project}-${var.env}"
  cidr_block = var.vpc_cidr
  azs        = var.azs

  public_subnet_cidrs       = local.public_subnet_cidrs
  private_app_subnet_cidrs  = local.private_app_subnet_cidrs
  private_data_subnet_cidrs = local.private_data_subnet_cidrs

  single_nat_gateway = var.single_nat_gateway

  tags = local.default_tags
}

# --- Cost guardrails ----------------------------------------------------------

module "finops" {
  source = "../../modules/finops"
  providers = {
    aws.billing = aws.billing
  }

  sns_topic_name        = "${var.project}-${var.env}-finops"
  notification_emails   = var.notification_emails
  monthly_budget_amount = var.budget_amount

  tags = local.default_tags
}
