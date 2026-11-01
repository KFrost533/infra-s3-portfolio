terraform {
  required_providers {
    archive = {
      source = "hashicorp/archive"
    }
  }
}

data "archive_file" "report" {
  type        = "zip"
  source_file = "${path.module}/code/report.py"
  output_path = "${path.root}/.terraform/portfolio-weekly-requests.zip"
}

resource "aws_lambda_function" "report" {
  function_name    = var.function_name
  role             = var.role_arn
  runtime          = "python3.13"
  handler          = "report.lambda_handler"
  filename         = data.archive_file.report.output_path
  source_code_hash = data.archive_file.report.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      DISTRIBUTION_ID = var.distribution_id
      TOPIC_ARN       = var.topic_arn
    }
  }
}
