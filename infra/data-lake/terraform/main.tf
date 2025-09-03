provider "aws" { region = var.region }

resource "aws_s3_bucket" "lake" {
  bucket = var.bucket_name
  force_destroy = false
  tags = { project = "scout-lake", layer = "medallion" }
}

resource "aws_s3_bucket_versioning" "v" {
  bucket = aws_s3_bucket.lake.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.lake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.lake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object_lock_configuration" "ol" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.lake.id
  rule { default_retention { mode = "COMPLIANCE"; days = 7 } }
}

# Deny non-SSL, deny unencrypted, deny public
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    principals { type = "*"; identifiers = ["*"] }
    resources = [
      aws_s3_bucket.lake.arn,
      "${aws_s3_bucket.lake.arn}/*"
    ]
    condition { test = "Bool"; variable = "aws:SecureTransport"; values = ["false"] }
  }
  statement {
    sid     = "DenyUnencryptedUploads"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    principals { type = "*"; identifiers = ["*"] }
    resources = ["${aws_s3_bucket.lake.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = var.kms_key_arn != "" ? ["aws:kms"] : ["AES256"]
    }
  }
}

resource "aws_s3_bucket_policy" "bp" {
  bucket = aws_s3_bucket.lake.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# Lifecycle rules per layer (prefix-based)
resource "aws_s3_bucket_lifecycle_configuration" "lc" {
  bucket = aws_s3_bucket.lake.id

  rule {
    id = "bronze"
    status = "Enabled"
    filter { prefix = "bronze/" }
    transition { days = var.bronze_infrequent_days; storage_class = "STANDARD_IA" }
    transition { days = var.bronze_glacier_days; storage_class = "GLACIER" }
    dynamic "expiration" {
      for_each = var.bronze_expire_days > 0 ? [1] : []
      content { days = var.bronze_expire_days }
    }
  }

  rule {
    id = "silver"
    status = "Enabled"
    filter { prefix = "silver/" }
    transition { days = var.silver_infrequent_days; storage_class = "STANDARD_IA" }
    transition { days = var.silver_glacier_days; storage_class = "GLACIER" }
    dynamic "expiration" {
      for_each = var.silver_expire_days > 0 ? [1] : []
      content { days = var.silver_expire_days }
    }
  }

  rule {
    id = "gold"
    status = "Enabled"
    filter { prefix = "gold/" }
    transition { days = var.gold_infrequent_days; storage_class = "STANDARD_IA" }
    transition { days = var.gold_glacier_days; storage_class = "GLACIER" }
    dynamic "expiration" {
      for_each = var.gold_expire_days > 0 ? [1] : []
      content { days = var.gold_expire_days }
    }
  }

  rule {
    id = "platinum"
    status = "Enabled"
    filter { prefix = "platinum/" }
    transition { days = var.platinum_infrequent_days; storage_class = "STANDARD_IA" }
    transition { days = var.platinum_glacier_days; storage_class = "GLACIER" }
    # platinum_expire_days defaults 0 (retain)
    dynamic "expiration" {
      for_each = var.platinum_expire_days > 0 ? [1] : []
      content { days = var.platinum_expire_days }
    }
  }
}

# Output canonical prefixes
output "lake_bucket"     { value = aws_s3_bucket.lake.bucket }
output "prefix_bronze"   { value = "s3://${aws_s3_bucket.lake.bucket}/bronze/" }
output "prefix_silver"   { value = "s3://${aws_s3_bucket.lake.bucket}/silver/" }
output "prefix_gold"     { value = "s3://${aws_s3_bucket.lake.bucket}/gold/" }
output "prefix_platinum" { value = "s3://${aws_s3_bucket.lake.bucket}/platinum/" }