output "deploy_role_arn" {
  description = "GitHub Actions deployment role ARN."
  value       = aws_iam_role.github_deploy.arn
}
