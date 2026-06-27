# Organization-wide singletons. Run from the management account.

data "aws_caller_identity" "management" {}

# --- Organization, OUs, member accounts --------------------------------------

module "organization" {
  source = "../modules/organization"

  member_accounts = local.member_accounts
  tags            = local.default_tags
}

# --- Service Control Policies -------------------------------------------------
# Baseline guardrails apply to every member OU but NOT to the management account
# (which keeps break-glass access). Region locking is scoped to the OUs that run
# workloads. Suspended accounts are quarantined.

module "scp_baseline" {
  source = "../modules/scp"

  name        = "baseline-guardrails"
  description = "Org-wide guardrails: protect audit/security tooling and the root user."
  target_ids = [
    module.organization.ou_ids["security"],
    module.organization.ou_ids["infrastructure"],
    module.organization.ou_ids["workloads"],
    module.organization.ou_ids["sandbox"],
  ]

  deny_leave_organization = true
  deny_disable_cloudtrail = true
  deny_disable_guardduty  = true
  require_imdsv2          = true
  deny_root_user          = true
  region_lock             = false

  tags = local.default_tags
}

module "scp_region_lock" {
  source = "../modules/scp"

  name        = "region-lock"
  description = "Restrict workloads and infrastructure to approved regions."
  target_ids = [
    module.organization.ou_ids["workloads"],
    module.organization.ou_ids["infrastructure"],
  ]

  # Only the region-lock guardrail here; the baseline above already covers the rest.
  deny_leave_organization = false
  deny_disable_cloudtrail = false
  deny_disable_guardduty  = false
  require_imdsv2          = false
  deny_root_user          = false
  region_lock             = true
  allowed_regions         = var.region_lock_allowed_regions

  tags = local.default_tags
}

module "scp_suspended" {
  source = "../modules/scp"

  name        = "quarantine"
  description = "Deny everything except Support for suspended accounts."
  target_ids  = [module.organization.ou_ids["suspended"]]

  deny_leave_organization = false
  deny_disable_cloudtrail = false
  deny_disable_guardduty  = false
  require_imdsv2          = false
  deny_root_user          = false

  additional_statements = [{
    Sid       = "DenyAllExceptSupport"
    Effect    = "Deny"
    NotAction = ["support:*"]
    Resource  = "*"
  }]

  tags = local.default_tags
}

# --- Centralized organization CloudTrail -------------------------------------

module "cloudtrail" {
  source = "../modules/cloudtrail-org"
  count  = var.enable_cross_account_baseline ? 1 : 0
  providers = {
    aws.management  = aws
    aws.log_archive = aws.log_archive
  }

  organization_id        = module.organization.organization_id
  management_account_id  = data.aws_caller_identity.management.account_id
  log_archive_account_id = var.log_archive_account_id
  region                 = var.region
  bucket_name            = var.cloudtrail_bucket_name

  tags = local.default_tags
}

# --- Organization detective controls (phase 2) -------------------------------

module "security_baseline" {
  source = "../modules/security-baseline"
  count  = var.enable_cross_account_baseline ? 1 : 0
  providers = {
    aws.management = aws
    aws.security   = aws.security
  }

  tags = local.default_tags
}

# --- IAM Identity Center ------------------------------------------------------

module "identity_center" {
  source = "../modules/identity-center"

  permission_sets = local.permission_sets
  groups          = local.identity_center_groups
  assignments     = local.identity_center_assignments
  account_ids     = module.organization.account_ids

  tags = local.default_tags
}

# --- GitHub OIDC deploy role --------------------------------------------------

# Deploy-role permissions, scoped to the service namespaces this landing zone
# actually manages (rather than blanket AdministratorAccess). Resource "*" is
# unavoidable here: organization, account and IAM-creation actions are not
# resource-constrainable, and most resources are created by this very role so
# their ARNs do not exist when the policy is written.
data "aws_iam_policy_document" "deploy" {
  # checkov:skip=CKV_AWS_111:Org/account/IAM creation actions cannot be resource-scoped.
  # checkov:skip=CKV_AWS_356:Resource "*" is required for create-time actions with no ARN.
  # checkov:skip=CKV_AWS_109:This is the org bootstrap role; permissions-management is its purpose, gated by OIDC + branch + 1h sessions.
  # checkov:skip=CKV_AWS_107:IAM credential actions are inherent to provisioning IAM for the landing zone.
  # checkov:skip=CKV_AWS_108:Broad service access is the deployer's function; egress is contained by OIDC federation, not this policy.
  # checkov:skip=CKV_AWS_110:Privilege management is required to create the org's roles and permission sets.
  # checkov:skip=CKV2_AWS_40:Full IAM access is required to manage org roles, OIDC and Identity Center.
  statement {
    sid    = "LandingZoneDeploy"
    effect = "Allow"
    actions = [
      "organizations:*",
      "account:*",
      "iam:*",
      "sso:*",
      "sso-directory:*",
      "identitystore:*",
      "s3:*",
      "kms:*",
      "dynamodb:*",
      "cloudtrail:*",
      "logs:*",
      "ec2:*",
      "budgets:*",
      "ce:*",
      "sns:*",
      "sts:AssumeRole",
    ]
    resources = ["*"]
  }
}

# Read-only role for PR plans. Pull requests (including from forks) can run
# `terraform plan`, which can execute code via data sources — so this role gets
# ReadOnlyAccess plus just enough to decrypt remote state, and nothing that can
# mutate the org.
data "aws_iam_policy_document" "plan_state" {
  # checkov:skip=CKV_AWS_111:kms:Decrypt on the state key is read-only; the key is created elsewhere so its ARN is not known here.
  # checkov:skip=CKV_AWS_356:Resource "*" scoped by the action set (decrypt only) and by the read-only role it attaches to.
  statement {
    sid       = "DecryptRemoteState"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]
  }
}

module "github_oidc_plan" {
  source = "../modules/github-oidc"

  github_org  = var.github_org
  github_repo = var.github_repo

  role_name           = "github-actions-plan"
  allowed_branches    = ["main"]
  allow_pull_requests = true # PRs may plan, but only read-only.

  permissions_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  inline_policy           = data.aws_iam_policy_document.plan_state.json

  create_oidc_provider = true

  tags = local.default_tags
}

# Privileged apply role. Restricted to pushes on main — never assumable from a
# pull request — and reuses the OIDC provider created above.
module "github_oidc_apply" {
  source = "../modules/github-oidc"

  github_org  = var.github_org
  github_repo = var.github_repo

  role_name           = "github-actions-apply"
  allowed_branches    = ["main"]
  allow_pull_requests = false

  inline_policy = data.aws_iam_policy_document.deploy.json

  create_oidc_provider = false

  tags = local.default_tags
}

# --- Organization-level FinOps -----------------------------------------------

module "finops_org" {
  source = "../modules/finops"
  providers = {
    aws.billing = aws.billing
  }

  sns_topic_name        = "org-finops"
  notification_emails   = var.finops_notification_emails
  monthly_budget_amount = var.org_budget_amount

  tags = local.default_tags
}
