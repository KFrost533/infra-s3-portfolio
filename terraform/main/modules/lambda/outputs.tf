output "function_name" {
  description = "Weekly request report Lambda function name."
  value       = aws_lambda_function.portfolio_report.function_name
}

output "function_arn" {
  description = "Weekly request report Lambda ARN."
  value       = aws_lambda_function.portfolio_report.arn
}