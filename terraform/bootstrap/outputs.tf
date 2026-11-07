output "github_oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN to use in terraform/main."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "apply_role_arn" {
  description = "Set as the GitHub Actions TF_APPLY_ROLE_ARN variable."
  value       = module.github_actions_roles.apply_role_arn
}

output "destroy_role_arn" {
  description = "Set as the GitHub Actions DESTROY_ROLE_ARN variable."
  value       = module.github_actions_roles.destroy_role_arn
}

output "aws_account_id" {
  description = "Set as the GitHub Actions AWS_ACCOUNT_ID and DESTROY_AWS_ACCOUNT_ID variables."
  value       = data.aws_caller_identity.current.account_id
}
