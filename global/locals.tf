locals {
  default_tags = {
    Project   = var.project
    Env       = "global"
    Owner     = var.owner
    ManagedBy = "terraform"
  }

  # Account-to-OU placement is a design decision, fixed here; operators only
  # supply the account emails.
  member_accounts = {
    "log-archive" = {
      name   = "log-archive"
      email  = var.account_emails.log_archive
      ou_key = "security"
    }
    "security" = {
      name   = "security"
      email  = var.account_emails.security
      ou_key = "security"
    }
    "shared-services" = {
      name   = "shared-services"
      email  = var.account_emails.shared_services
      ou_key = "infrastructure"
    }
    "workloads-dev" = {
      name   = "workloads-dev"
      email  = var.account_emails.workloads_dev
      ou_key = "workloads_dev"
    }
    "workloads-prod" = {
      name   = "workloads-prod"
      email  = var.account_emails.workloads_prod
      ou_key = "workloads_prod"
    }
  }

  # Least-privilege permission sets. AdministratorAccess is break-glass only:
  # short session, assigned narrowly.
  permission_sets = {
    AdministratorAccess = {
      description         = "Break-glass full access (short-lived)."
      session_duration    = "PT1H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
    }
    PowerUserDev = {
      description         = "Developer access without IAM administration."
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/PowerUserAccess"]
    }
    ReadOnly = {
      description         = "Read-only access for auditors and support."
      session_duration    = "PT8H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
    SecurityAudit = {
      description         = "Security auditing across accounts."
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/SecurityAudit"]
    }
    Billing = {
      description         = "Billing and cost management."
      session_duration    = "PT4H"
      managed_policy_arns = ["arn:aws:iam::aws:policy/job-function/Billing"]
    }
  }

  identity_center_groups = [
    "Administrators",
    "Developers",
    "Auditors",
    "FinOps",
  ]

  # group -> account -> permission set
  identity_center_assignments = [
    { group_name = "Administrators", account_name = "workloads-prod", permission_set_name = "AdministratorAccess" },
    { group_name = "Administrators", account_name = "workloads-dev", permission_set_name = "AdministratorAccess" },
    { group_name = "Developers", account_name = "workloads-dev", permission_set_name = "PowerUserDev" },
    { group_name = "Developers", account_name = "workloads-prod", permission_set_name = "ReadOnly" },
    { group_name = "Auditors", account_name = "security", permission_set_name = "SecurityAudit" },
    { group_name = "Auditors", account_name = "log-archive", permission_set_name = "SecurityAudit" },
    { group_name = "Auditors", account_name = "workloads-prod", permission_set_name = "ReadOnly" },
    { group_name = "FinOps", account_name = "shared-services", permission_set_name = "Billing" },
  ]
}
