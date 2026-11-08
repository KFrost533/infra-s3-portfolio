variable "bucket_arn" {
  description = "ARN of the portfolio bucket permitted for HTML uploads."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution permitted for cache invalidation."
  type        = string
}

variable "deploy_role_name" {
  description = "IAM role name used by the GitHub Actions deployment."
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "GitHub OIDC provider ARN managed by the bootstrap stack."
  type        = string
  nullable    = false
}

variable "github_repository" {
  description = "GitHub owner and repository permitted to deploy from the main branch."
  type        = string
}

variable "github_repository_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject claim."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject claim."
  type        = string
}
