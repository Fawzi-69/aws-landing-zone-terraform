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

# Log-archive account, reached by assuming the org access role.
#
# Two-phase bootstrap (clean, no -target hack): the account id is supplied as an
# operator variable rather than read from module.organization, so the provider
# does NOT depend on a resource that does not yet exist.
#   Phase 1 — set create_member_accounts only and apply; read the new account id
#             from `terraform output account_ids`.
#   Phase 2 — set log_archive_account_id to that value and apply again to wire
#             the cross-account CloudTrail.
# Until the id is known, leave the variable empty: the cross-account modules are
# gated off (see enable_cross_account_baseline) so this provider is unused.
provider "aws" {
  alias  = "log_archive"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.log_archive_account_id}:role/${var.member_account_access_role}"
  }

  default_tags {
    tags = local.default_tags
  }
}

# Security account, delegated administrator for detective controls. Same phase-2
# pattern: the account id comes from a variable, not a module output.
provider "aws" {
  alias  = "security"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.security_account_id}:role/${var.member_account_access_role}"
  }

  default_tags {
    tags = local.default_tags
  }
}
