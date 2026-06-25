# AWS Organizations: the root of the landing zone. Creates the organization
# (feature set ALL so SCPs can be enforced), the OU hierarchy, and the member
# accounts. Account placement is driven by each account's `ou_key`.

resource "aws_organizations_organization" "this" {
  feature_set                   = "ALL"
  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = var.enabled_policy_types
}

# --- Organizational Units -----------------------------------------------------
# Top level: Security, Infrastructure, Workloads, Sandbox, Suspended.
# Workloads is split into Dev and Prod children.

resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads_dev" {
  name      = "Dev"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "workloads_prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

resource "aws_organizations_organizational_unit" "suspended" {
  name      = "Suspended"
  parent_id = aws_organizations_organization.this.roots[0].id
  tags      = var.tags
}

locals {
  ou_ids = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    workloads      = aws_organizations_organizational_unit.workloads.id
    workloads_dev  = aws_organizations_organizational_unit.workloads_dev.id
    workloads_prod = aws_organizations_organizational_unit.workloads_prod.id
    sandbox        = aws_organizations_organizational_unit.sandbox.id
    suspended      = aws_organizations_organizational_unit.suspended.id
  }
}

# --- Member accounts ----------------------------------------------------------

resource "aws_organizations_account" "this" {
  for_each = var.member_accounts

  name      = each.value.name
  email     = each.value.email
  parent_id = local.ou_ids[each.value.ou_key]

  # Closing an account is an explicit, deliberate action — off by default.
  close_on_deletion = each.value.close_on_deletion

  tags = var.tags

  lifecycle {
    # The cross-account access role name is set once at creation; AWS does not
    # let it change in place.
    ignore_changes = [role_name]
  }
}
