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
  description = "Existing GitHub OIDC provider ARN, or null to create one."
  type        = string
}

variable "github_repository" {
  description = "GitHub owner and repository permitted to deploy from the main branch."
  type        = string
}

variable "enable_request_report" {
  description = "Whether to create the request reporting roles."
  type        = bool
}

variable "report_topic_arn" {
  description = "SNS topic ARN for the request report, or null when disabled."
  type        = string
}

variable "report_function_name" {
  description = "Name of the request reporting Lambda function."
  type        = string
}

variable "aws_region" {
  description = "Region hosting the request reporting Lambda and SNS topic."
  type        = string
}
