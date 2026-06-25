# Default provider = the management (payer) account, where AWS Organizations,
# Identity Center and the GitHub OIDC provider live.
provider "aws" {
  region = var.region

  default_tags {
    tags = local.default_tags
  }
}

# Billing endpoint (us-east-1) for the org-level Budgets / Cost Explorer.
provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  default_tags {
    tags = local.default_tags
  }
}

# Log-archive account, reached by assuming the org access role created with the
# account. NOTE (two-phase bootstrap): the member accounts must exist before
# this provider can authenticate, so the very first apply is run targeting the
# organization module (`-target=module.organization`), after which a normal
# apply provisions the cross-account CloudTrail resources.
provider "aws" {
  alias  = "log_archive"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${module.organization.account_ids["log-archive"]}:role/${var.member_account_access_role}"
  }

  default_tags {
    tags = local.default_tags
  }
}
