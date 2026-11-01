variable "aws_region" {
  description = "AWS region for the portfolio bucket."
  type        = string
  default     = "ap-southeast-2"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for the portfolio."
  type        = string
  default     = "kfrost533-portfolio-s3"
}

variable "domain_name" {
  description = "Public domain name for the portfolio, such as portfolio.example.com."
  type        = string
  default     = "kfrost533-portfolio.com"
}

variable "hosted_zone_name" {
  description = "DNS domain of the new public Route 53 hosted zone, not a descriptive label."
  type        = string
  default     = "kfrost533-portfolio.com"
}

variable "github_repository" {
  description = "GitHub owner and repository permitted to deploy from the main branch."
  type        = string
  default     = "KFrost533/infra-s3-portfolio"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "The GitHub repository must be in owner/repository format."
  }
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN, or null to create one."
  type        = string
  default     = null

  validation {
    condition     = var.github_oidc_provider_arn == null ? true : can(regex("^arn:[^:]+:iam::[0-9]{12}:oidc-provider/token[.]actions[.]githubusercontent[.]com$", var.github_oidc_provider_arn))
    error_message = "The OIDC provider ARN must identify the GitHub Actions provider."
  }
}

variable "deploy_role_name" {
  description = "IAM role name used by the GitHub Actions deployment."
  type        = string
  default     = "portfolio-github-actions-deploy"
}
