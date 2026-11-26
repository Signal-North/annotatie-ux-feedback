data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  partition    = data.aws_partition.current.partition
  name         = "annotatie"
  state_bucket = "${local.name}-tfstate-${local.account_id}"
  repo_full    = "${var.github_owner}/${var.github_repo}"

  certificate_domain = coalesce(var.certificate_domain, var.route53_zone)
  # Route 53's normalised form: lower case, no trailing dot.
  site_record_name = lower(trimsuffix(var.domain_name, "."))
}

# The existing zone the platform's one A record lives in (never created here).
data "aws_route53_zone" "site" {
  name         = var.route53_zone
  private_zone = false
}

# Refuse to bootstrap the wrong account (your default profile may point elsewhere).
resource "terraform_data" "account_guard" {
  lifecycle {
    precondition {
      condition     = local.account_id == var.expected_account_id
      error_message = "Credentials are for account ${local.account_id}, not ${var.expected_account_id}. Switch profile."
    }
  }
}

# ---------------------------------------------------------------- state bucket
resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
  lifecycle {
    prevent_destroy = true
  }
  depends_on = [terraform_data.account_guard]
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
      sse_algorithm = "AES256" # SSE-S3: free (C-2)
    }
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
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "state_tls_only" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*",
    ]
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

# ---------------------------------------------------------------- budget (C-16)
resource "aws_budgets_budget" "monthly" {
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # In a shared account an unfiltered budget measures everyone's spend. The tag only counts once it
  # is activated as a cost-allocation tag in Billing.
  dynamic "cost_filter" {
    for_each = var.budget_filter_by_project_tag ? [1] : []
    content {
      name   = "TagKeyValue"
      values = [format("user:project$%s", local.name)] # user:project$annotatie
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_email]
  }

  depends_on = [terraform_data.account_guard]
}
