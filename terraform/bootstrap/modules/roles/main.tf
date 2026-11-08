locals {
  role_names = [
    var.deploy_role_name,
    "${var.report_function_name}-lambda-role",
    "${var.report_function_name}-scheduler-role",
  ]
  role_arns              = [for name in local.role_names : "arn:${var.partition}:iam::${var.account_id}:role/${name}"]
  zone_arn               = "arn:${var.partition}:route53:::hostedzone/${var.hosted_zone_id}"
  portfolio_function_arn = "arn:${var.partition}:lambda:${var.aws_region}:${var.account_id}:function:${var.report_function_name}"
  schedule_arn           = "arn:${var.partition}:scheduler:${var.aws_region}:${var.account_id}:schedule/default/${var.report_function_name}"
  topic_arn              = "arn:${var.partition}:sns:${var.aws_region}:${var.account_id}:portfolio-weekly-requests"
  log_group_arn          = "arn:${var.partition}:logs:${var.aws_region}:${var.account_id}:log-group:/aws/lambda/${var.report_function_name}:*"
  parameter_name         = trimprefix(var.request_report_email_parameter, "/")
  parameter_arn          = "arn:${var.partition}:ssm:${var.aws_region}:${var.account_id}:parameter/${local.parameter_name}"
  destroy_services = [
    "acm:*",
    "cloudfront:*",
    "wafv2:*",
  ]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.oidc_subject]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = var.apply_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role" "destroy" {
  name                 = var.destroy_role_name
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "apply" {
  statement {
    sid       = "TerraformStateAccess"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }
  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.state_bucket_arn}/portfolio/terraform.tfstate"]
  }
  statement {
    sid       = "TerraformStateLockFiles"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/portfolio/terraform.tfstate.tflock"]
  }
  statement {
    sid       = "ManagePortfolioBucket"
    actions   = ["s3:*"]
    resources = [var.portfolio_bucket_arn, "${var.portfolio_bucket_arn}/*"]
  }
  statement {
    sid       = "ManageCertificates"
    actions   = ["acm:*"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageCloudFrontDistribution"
    actions   = ["cloudfront:*"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageCountOnlyWaf"
    actions   = ["wafv2:*"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageHostedZoneRecords"
    actions   = ["route53:*"]
    resources = [local.zone_arn]
  }
  statement {
    sid       = "ReadHostedZoneAndChanges"
    actions   = ["route53:GetChange", "route53:ListHostedZones"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageProjectRoles"
    actions   = ["iam:*"]
    resources = local.role_arns
  }
  statement {
    sid       = "PassProjectRolesToServices"
    actions   = ["iam:PassRole"]
    resources = local.role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "scheduler.amazonaws.com"]
    }
  }
  statement {
    sid       = "ListRolesForTerraform"
    actions   = ["iam:ListRoles"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageReportFunction"
    actions   = ["lambda:*"]
    resources = [local.portfolio_function_arn]
  }
  statement {
    sid       = "ManageReportSchedule"
    actions   = ["scheduler:*"]
    resources = [local.schedule_arn]
  }
  statement {
    sid       = "ManageReportTopic"
    actions   = ["logs:*"]
    resources = [local.log_group_arn]
  }
  statement {
    sid       = "DiscoverReportLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
  statement {
    sid       = "ReadReportEmailParameter"
    actions   = ["ssm:GetParameter"]
    resources = [local.parameter_arn]
  }
  statement {
    sid       = "DecryptSecureStringParameter"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:PARAMETER_ARN"
      values   = [local.parameter_arn]
    }
  }
  statement {
    sid       = "IdentifyAccount"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "portfolio-terraform-apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}

data "aws_iam_policy_document" "destroy" {
  statement {
    sid       = "TerraformStateAccess"
    actions   = ["s3:ListBucket"]
    resources = [var.state_bucket_arn]
  }
  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${var.state_bucket_arn}/portfolio/terraform.tfstate"]
  }
  statement {
    sid       = "TerraformStateLockFiles"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${var.state_bucket_arn}/portfolio/terraform.tfstate.tflock"]
  }
  statement {
    sid       = "DeletePortfolioBucketVersions"
    actions   = ["s3:ListBucket", "s3:ListBucketVersions"]
    resources = [var.portfolio_bucket_arn]
  }
  statement {
    sid       = "ManagePortfolioBucketAndObjects"
    actions   = ["s3:*"]
    resources = [var.portfolio_bucket_arn, "${var.portfolio_bucket_arn}/*"]
  }
  statement {
    sid       = "ManageRegionalInfrastructure"
    actions   = local.destroy_services
    resources = ["*"]
  }
  statement {
    sid       = "ManageHostedZoneRecords"
    actions   = ["route53:*"]
    resources = [local.zone_arn]
  }
  statement {
    sid       = "ReadHostedZoneAndChanges"
    actions   = ["route53:GetChange", "route53:ListHostedZones"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageProjectRoles"
    actions   = ["iam:*"]
    resources = local.role_arns
  }
  statement {
    sid       = "PassProjectRolesToServices"
    actions   = ["iam:PassRole"]
    resources = local.role_arns

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "scheduler.amazonaws.com"]
    }
  }
  statement {
    sid       = "ListRolesForTerraform"
    actions   = ["iam:ListRoles"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageReportFunction"
    actions   = ["lambda:*"]
    resources = [local.portfolio_function_arn]
  }
  statement {
    sid       = "ManageReportSchedule"
    actions   = ["scheduler:*"]
    resources = [local.schedule_arn]
  }
  statement {
    sid       = "ManageReportTopic"
    actions   = ["sns:*"]
    resources = [local.topic_arn, "${local.topic_arn}:*"]
  }
  statement {
    sid = "ManageReportLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:ListTagsForResource",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = [local.log_group_arn]
  }
  statement {
    sid       = "DiscoverReportLogGroups"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }
  statement {
    sid       = "ReadReportEmailParameter"
    actions   = ["ssm:GetParameter"]
    resources = [local.parameter_arn]
  }
  statement {
    sid       = "DecryptSecureStringParameter"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:EncryptionContext:PARAMETER_ARN"
      values   = [local.parameter_arn]
    }
  }
  statement {
    sid       = "IdentifyAccount"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "destroy" {
  name   = "portfolio-terraform-destroy"
  role   = aws_iam_role.destroy.id
  policy = data.aws_iam_policy_document.destroy.json
}
