variable "bucket_arn" {
  description = "ARN of the portfolio bucket permitted for HTML uploads."
  type        = string
}

variable "deploy_role_name" {
  description = "IAM role name used by the GitHub Actions deployment."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, or null to create one."
  type        = string
}

variable "github_repository" {
  description = "GitHub owner and repository permitted to deploy from the main branch."
  type        = string
}
