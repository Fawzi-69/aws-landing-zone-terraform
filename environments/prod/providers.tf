# Both providers assume the cross-account role in the target workloads account.
# The default provider runs in the workload region; the billing alias runs in
# us-east-1 for Budgets / Cost Explorer.

provider "aws" {
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.member_account_access_role}"
  }

  default_tags {
    tags = local.default_tags
  }
}

provider "aws" {
  alias  = "billing"
  region = "us-east-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/${var.member_account_access_role}"
  }

  default_tags {
    tags = local.default_tags
  }
}
