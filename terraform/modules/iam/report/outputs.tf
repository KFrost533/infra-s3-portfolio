output "deploy_role_arn" {
  description = "GitHub Actions deployment role ARN."
  value       = aws_iam_role.github_deploy.arn
}

output "report_lambda_role_arn" {
  description = "Execution role ARN for the optional request report Lambda."
  value       = var.enable_request_report ? aws_iam_role.report_lambda[0].arn : null
  depends_on  = [aws_iam_role_policy.report_lambda]
}

output "report_scheduler_role_arn" {
  description = "Execution role ARN for the optional report schedule."
  value       = var.enable_request_report ? aws_iam_role.report_scheduler[0].arn : null
  depends_on  = [aws_iam_role_policy.report_scheduler]
}
