# Bootstrap: provisions the remote state backend (S3 + DynamoDB) that every
# other root configuration consumes via a partial backend config.
#
# This root keeps its OWN state local (committed nowhere) because it cannot use
# the backend it is in charge of creating — the classic chicken-and-egg case.

# --- KMS key encrypting both the state bucket and the lock table --------------

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "state_kms" {
  # Delegate key administration to the account's IAM (root principal = account),
  # so IAM policies/roles govern access. "*" here scopes to THIS key only — a
  # KMS key policy's resource is always the key it is attached to.
  # checkov:skip=CKV_AWS_109:KMS key policy resource is implicitly the key itself; kms:* to the account root is AWS's recommended baseline to avoid key lockout.
  # checkov:skip=CKV_AWS_111:Same — root-account admin on the key prevents an unrecoverable lockout; access is then governed by IAM.
  # checkov:skip=CKV_AWS_356:"*" in a KMS key policy refers only to this key, not to all resources.
  statement {
    sid       = "EnableIamUserPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_kms_key" "state" {
  description             = "Encrypts Terraform remote state (S3) and lock table (DynamoDB)."
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.state_kms.json
}

resource "aws_kms_alias" "state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.state.key_id
}

# --- State bucket -------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket_name

  # State is the source of truth; never allow Terraform to delete a non-empty
  # bucket by accident.
  force_destroy = false

  # checkov:skip=CKV_AWS_18:This bucket is the central state store; wiring S3
  # access logging here would require a second bucket that itself needs logging
  # (recursive). Access to state is audited via the org CloudTrail data events.
  # checkov:skip=CKV2_AWS_62:No event-notification consumer for the state bucket.
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Deny any non-TLS access to the state bucket.
data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

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

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_tls_only.json
}

# --- Lock table ---------------------------------------------------------------

resource "aws_dynamodb_table" "lock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.state.arn
  }

  # Guard against accidental table deletion (would orphan all state locks).
  deletion_protection_enabled = true
}
