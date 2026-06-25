# Reusable Service Control Policy. Each guardrail is an independent toggle so
# the same module can produce a strict root baseline, a region-locked Workloads
# policy, or a hardened Sandbox policy. SCPs only ever DENY, so they never grant
# access — they cap what identities in the targeted accounts can do.

locals {
  statements = concat(
    var.deny_leave_organization ? [{
      Sid      = "DenyLeaveOrganization"
      Effect   = "Deny"
      Action   = ["organizations:LeaveOrganization"]
      Resource = "*"
    }] : [],

    var.deny_disable_cloudtrail ? [{
      Sid    = "DenyDisableCloudTrail"
      Effect = "Deny"
      Action = [
        "cloudtrail:StopLogging",
        "cloudtrail:DeleteTrail",
        "cloudtrail:UpdateTrail",
        "cloudtrail:PutEventSelectors",
      ]
      Resource = "*"
    }] : [],

    var.deny_disable_guardduty ? [{
      Sid    = "DenyDisableGuardDuty"
      Effect = "Deny"
      Action = [
        "guardduty:DeleteDetector",
        "guardduty:DisassociateFromMasterAccount",
        "guardduty:StopMonitoringMembers",
        "guardduty:UpdateDetector",
        "guardduty:DeleteMembers",
      ]
      Resource = "*"
    }] : [],

    var.require_imdsv2 ? [{
      Sid      = "RequireImdsv2"
      Effect   = "Deny"
      Action   = "ec2:RunInstances"
      Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = {
        StringNotEquals = {
          "ec2:MetadataHttpTokens" = "required"
        }
      }
    }] : [],

    var.deny_root_user ? [{
      Sid      = "DenyRootUser"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
      Condition = {
        StringLike = {
          "aws:PrincipalArn" = "arn:aws:iam::*:root"
        }
      }
    }] : [],

    var.region_lock ? [{
      Sid       = "RegionLock"
      Effect    = "Deny"
      NotAction = var.region_lock_global_services
      Resource  = "*"
      Condition = {
        StringNotEquals = {
          "aws:RequestedRegion" = var.allowed_regions
        }
      }
    }] : [],

    var.additional_statements,
  )
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = var.tags

  content = jsonencode({
    Version   = "2012-10-17"
    Statement = local.statements
  })

  lifecycle {
    precondition {
      condition     = length(local.statements) > 0
      error_message = "At least one guardrail toggle or additional statement must be set; an SCP cannot be empty."
    }
  }
}

resource "aws_organizations_policy_attachment" "this" {
  for_each = toset(var.target_ids)

  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
