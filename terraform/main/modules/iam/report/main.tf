data "aws_partition" "report" {
  count = var.enable_request_report ? 1 : 0
}

data "aws_caller_identity" "report" {
  count = var.enable_request_report ? 1 : 0
}

data "aws_iam_policy_document" "report_lambda_trust" {
  count = var.enable_request_report ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "report_lambda" {
  count              = var.enable_request_report ? 1 : 0
  name               = "${var.report_function_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.report_lambda_trust[0].json
}

data "aws_iam_policy_document" "report_lambda" {
  count = var.enable_request_report ? 1 : 0

  statement {
    actions   = ["cloudwatch:GetMetricData"]
    resources = ["*"]
  }

  statement {
    actions   = ["sns:Publish"]
    resources = [var.report_topic_arn]
  }

  statement {
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:${data.aws_partition.report[0].partition}:logs:${var.aws_region}:${data.aws_caller_identity.report[0].account_id}:log-group:/aws/lambda/${var.report_function_name}:*"]
  }
}

resource "aws_iam_role_policy" "report_lambda" {
  count  = var.enable_request_report ? 1 : 0
  name   = "weekly-request-report"
  role   = aws_iam_role.report_lambda[0].id
  policy = data.aws_iam_policy_document.report_lambda[0].json
}

data "aws_iam_policy_document" "report_scheduler_trust" {
  count = var.enable_request_report ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.report[0].account_id]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.report[0].partition}:scheduler:${var.aws_region}:${data.aws_caller_identity.report[0].account_id}:schedule-group/default"]
    }
  }
}

resource "aws_iam_role" "report_scheduler" {
  count              = var.enable_request_report ? 1 : 0
  name               = "${var.report_function_name}-scheduler-role"
  assume_role_policy = data.aws_iam_policy_document.report_scheduler_trust[0].json
}

data "aws_iam_policy_document" "report_scheduler" {
  count = var.enable_request_report ? 1 : 0

  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.report[0].partition}:lambda:${var.aws_region}:${data.aws_caller_identity.report[0].account_id}:function:${var.report_function_name}"]
  }
}

resource "aws_iam_role_policy" "report_scheduler" {
  count  = var.enable_request_report ? 1 : 0
  name   = "invoke-weekly-request-report"
  role   = aws_iam_role.report_scheduler[0].id
  policy = data.aws_iam_policy_document.report_scheduler[0].json
}
