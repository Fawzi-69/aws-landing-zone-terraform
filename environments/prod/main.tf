# Per-account baseline for the workloads-prod account: account-level hardening,
# a segmented VPC, and environment cost guardrails.

# --- Account hardening --------------------------------------------------------

module "account_baseline" {
  source = "../../modules/account-baseline"
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
