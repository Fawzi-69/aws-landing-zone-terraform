# IAM Identity Center (AWS SSO) wiring: permission sets, groups, and the
# group -> account -> permission-set assignments that grant least-privilege
# access. The Identity Center instance itself must be enabled beforehand (it is
# a one-time, account-level action that cannot be created via this provider);
# we look it up here.

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  # Flatten managed-policy attachments into one entry per (permission set, arn).
  managed_attachments = flatten([
    for ps_name, ps in var.permission_sets : [
      for arn in ps.managed_policy_arns : {
        key     = "${ps_name}::${arn}"
        ps_name = ps_name
        arn     = arn
      }
    ]
  ])

  # Same for customer-managed policy references.
  customer_attachments = flatten([
    for ps_name, ps in var.permission_sets : [
      for pname in ps.customer_managed_policy_names : {
        key     = "${ps_name}::${pname}"
        ps_name = ps_name
        name    = pname
      }
    ]
  ])
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.instance_arn
  session_duration = each.value.session_duration
  tags             = var.tags
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = { for m in local.managed_attachments : m.key => m }

  instance_arn       = local.instance_arn
  managed_policy_arn = each.value.arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_name].arn
}

resource "aws_ssoadmin_customer_managed_policy_attachment" "this" {
  for_each = { for c in local.customer_attachments : c.key => c }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_name].arn

  customer_managed_policy_reference {
    name = each.value.name
    path = "/"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = { for k, ps in var.permission_sets : k => ps if ps.inline_policy != "" }

  inline_policy      = each.value.inline_policy
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
}

resource "aws_identitystore_group" "this" {
  for_each = toset(var.groups)

  identity_store_id = local.identity_store_id
  display_name      = each.value
  description       = "Managed by Terraform"
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = {
    for a in var.assignments :
    "${a.group_name}::${a.account_name}::${a.permission_set_name}" => a
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set_name].arn

  principal_id   = aws_identitystore_group.this[each.value.group_name].group_id
  principal_type = "GROUP"

  target_id   = var.account_ids[each.value.account_name]
  target_type = "AWS_ACCOUNT"
}
