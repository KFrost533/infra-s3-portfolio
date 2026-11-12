data "aws_s3_bucket" "portfolio" {
  bucket = var.bucket_name
}

removed {
  from = aws_s3_bucket.portfolio
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_s3_bucket_public_access_block.portfolio
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_s3_bucket_versioning.portfolio
  lifecycle {
    destroy = false
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid     = "AllowCloudFrontRead"
    actions = ["s3:GetObject"]
    resources = [
      "${data.aws_s3_bucket.portfolio.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [var.cloudfront_distribution_arn]
    }
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      data.aws_s3_bucket.portfolio.arn,
      "${data.aws_s3_bucket.portfolio.arn}/*"
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

resource "aws_s3_bucket_policy" "portfolio" {
  bucket = data.aws_s3_bucket.portfolio.id
  policy = data.aws_iam_policy_document.bucket.json
}
