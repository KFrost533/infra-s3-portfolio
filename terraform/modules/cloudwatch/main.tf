resource "aws_cloudwatch_log_group" "report" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 30
}