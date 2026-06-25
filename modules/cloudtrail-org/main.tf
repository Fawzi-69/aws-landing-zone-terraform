# Organization-wide CloudTrail with centralized storage in the log-archive
# account. The trail lives in the management account; the encrypted bucket and
# KMS key live in log-archive, isolating audit logs from the accounts that
# generate them. Cross-account access is granted by the bucket and key policies.

locals {
  trail_arn = "arn:aws:cloudtrail:${var.region}:${var.management_account_id}:trail/${var.trail_name}"
}

# =============================================================================
# Log-archive account: KMS key + destination bucket
# =============================================================================

data "aws_iam_policy_document" "trail_kms" {
  # Account root retains administrative control of the key (prevents lockout).
  # "*" resource scopes to this key only.
  # checkov:skip=CKV_AWS_109:KMS key policy resource is implicitly this key; root admin avoids lockout.
  # checkov:skip=CKV_AWS_111:Root-account admin on the key is the AWS-recommended baseline.
  # checkov:skip=CKV_AWS_356:"*" in a KMS key policy refers only to this key.
  statement {
    sid       = "EnableIamUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.log_archive_account_id}:root"]
    }
  }

  statement {
    sid       = "AllowCloudTrailEncrypt"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${var.management_account_id}:trail/*"]
    }
  }
}

resource "aws_kms_key" "trail" {
  provider                = aws.log_archive
  description             = "Encrypts the organization CloudTrail logs."
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.trail_kms.json
  tags                    = var.tags
}

resource "aws_kms_alias" "trail" {
  provider      = aws.log_archive
  name          = "alias/org-cloudtrail"
  target_key_id = aws_kms_key.trail.key_id
}

resource "aws_s3_bucket" "trail" {
  provider      = aws.log_archive
  bucket        = var.bucket_name
  force_destroy = false

  # checkov:skip=CKV_AWS_18:This is the central audit-log bucket; adding S3 access
  # logging would require a second log bucket that also needs logging (recursive).
  # checkov:skip=CKV2_AWS_62:No event-notification consumer for the audit bucket.
  tags = var.tags
}

resource "aws_s3_bucket_versioning" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.trail.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  provider                = aws.log_archive
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id

  rule {
    id     = "retain-then-expire"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid     = "AWSCloudTrailWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    # Org trails write under AWSLogs/<org-id>/<account-id>/...; also allow the
    # management account's own path.
    resources = [
      "${aws_s3_bucket.trail.arn}/AWSLogs/${var.organization_id}/*",
      "${aws_s3_bucket.trail.arn}/AWSLogs/${var.management_account_id}/*",
    ]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  policy   = data.aws_iam_policy_document.trail_bucket.json
}

# =============================================================================
# Management account: CloudWatch log group + role + the trail itself
# =============================================================================

resource "aws_cloudwatch_log_group" "trail" {
  provider          = aws.management
  name              = "/aws/cloudtrail/${var.trail_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.trail.arn
  tags              = var.tags
}

data "aws_iam_policy_document" "trail_cw_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "trail_cw" {
  provider           = aws.management
  name               = "${var.trail_name}-cloudwatch-delivery"
  assume_role_policy = data.aws_iam_policy_document.trail_cw_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "trail_cw" {
  statement {
    sid       = "AllowCloudTrailToCloudWatchLogs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.trail.arn}:*"]
  }
}

resource "aws_iam_role_policy" "trail_cw" {
  provider = aws.management
  name     = "cloudwatch-delivery"
  role     = aws_iam_role.trail_cw.id
  policy   = data.aws_iam_policy_document.trail_cw.json
}

resource "aws_cloudtrail" "org" {
  provider = aws.management

  # checkov:skip=CKV_AWS_252:Log delivery is wired to CloudWatch Logs (and thus
  # EventBridge) for alerting; per-log-file SNS notifications are legacy and noisy.
  name           = var.trail_name
  s3_bucket_name = aws_s3_bucket.trail.id

  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = var.enable_log_file_validation
  enable_logging                = true

  kms_key_id = aws_kms_key.trail.arn

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.trail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.trail_cw.arn

  tags = var.tags

  depends_on = [
    aws_s3_bucket_policy.trail,
    aws_iam_role_policy.trail_cw,
  ]
}
