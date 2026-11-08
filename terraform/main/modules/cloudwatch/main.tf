resource "aws_cloudwatch_log_group" "portfolio_report" {
  name              = "/aws/lambda/${var.portfolio_function_name}"
  retention_in_days = 30
}