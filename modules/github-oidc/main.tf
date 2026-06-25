# GitHub Actions -> AWS authentication via OpenID Connect: no long-lived keys.
# A workflow presents a signed OIDC token; the role's trust policy only accepts
# it for this exact repository and the allowed branches (and, optionally, pull
# requests). Permissions are supplied by the caller, keeping the module agnostic
# of what the pipeline is allowed to do.

locals {
  oidc_url = "https://token.actions.githubusercontent.com"

  branch_subjects = [
    for b in var.allowed_branches :
    "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${b}"
  ]
  pr_subjects = var.allow_pull_requests ? [
    "repo:${var.github_org}/${var.github_repo}:pull_request"
  ] : []
  subjects = concat(local.branch_subjects, local.pr_subjects)

  provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.existing[0].arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url            = local.oidc_url
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates the IdP certificate against its trust store; the thumbprint is
  # retained for backwards compatibility (GitHub's intermediate CA).
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = var.tags
}

data "aws_iam_openid_connect_provider" "existing" {
  count = var.create_oidc_provider ? 0 : 1
  url   = local.oidc_url
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.subjects
    }
  }
}

resource "aws_iam_role" "deploy" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.permissions_policy_arns)

  role       = aws_iam_role.deploy.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "inline" {
  count = var.inline_policy != "" ? 1 : 0

  name   = "${var.role_name}-inline"
  role   = aws_iam_role.deploy.id
  policy = var.inline_policy
}
