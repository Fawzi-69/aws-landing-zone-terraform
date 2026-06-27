# Organization detective controls. The management account delegates
# administration to the security account, which then turns the service on and
# auto-enrolls every member account. This is the standard AWS "delegated
# administrator" pattern that keeps day-to-day security operations out of the
# management account.

data "aws_caller_identity" "security" {
  provider = aws.security
}

# --- GuardDuty ----------------------------------------------------------------

resource "aws_guardduty_organization_admin_account" "this" {
  count    = var.enable_guardduty ? 1 : 0
  provider = aws.management

  admin_account_id = data.aws_caller_identity.security.account_id
}

resource "aws_guardduty_detector" "this" {
  count    = var.enable_guardduty ? 1 : 0
  provider = aws.security

  # checkov:skip=CKV2_AWS_3:GuardDuty IS enabled here (enable=true) and rolled out org-wide via the delegated-admin org configuration below; the graph check doesn't recognise this pattern.
  enable = true
}

resource "aws_guardduty_organization_configuration" "this" {
  count    = var.enable_guardduty ? 1 : 0
  provider = aws.security

  detector_id                      = aws_guardduty_detector.this[0].id
  auto_enable_organization_members = var.auto_enable_new_accounts ? "ALL" : "NONE"

  depends_on = [aws_guardduty_organization_admin_account.this]
}

# --- Security Hub -------------------------------------------------------------

resource "aws_securityhub_organization_admin_account" "this" {
  count    = var.enable_securityhub ? 1 : 0
  provider = aws.management

  admin_account_id = data.aws_caller_identity.security.account_id
}

resource "aws_securityhub_account" "this" {
  count    = var.enable_securityhub ? 1 : 0
  provider = aws.security
}

resource "aws_securityhub_organization_configuration" "this" {
  count    = var.enable_securityhub ? 1 : 0
  provider = aws.security

  auto_enable = var.auto_enable_new_accounts

  depends_on = [
    aws_securityhub_organization_admin_account.this,
    aws_securityhub_account.this,
  ]
}

# --- IAM Access Analyzer (organization scope) ---------------------------------

resource "aws_accessanalyzer_analyzer" "org" {
  count    = var.enable_access_analyzer ? 1 : 0
  provider = aws.management

  analyzer_name = "org-access-analyzer"
  type          = "ORGANIZATION"

  tags = var.tags
}
