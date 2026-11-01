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
  default     = "kfrost533.click"
}

variable "record_name" {
  description = "The name of the DNS record for the portfolio domain."
  type        = string
  default     = "portfolio"
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

variable "github_repository_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject claim."
  type        = string
  default     = "155362696"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_owner_id))
    error_message = "The GitHub owner ID must contain only digits."
  }
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject claim."
  type        = string
  default     = "1441557129"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "The GitHub repository ID must contain only digits."
  }
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN; set to null only when Terraform should create one."
  type        = string
  default     = "arn:aws:iam::204806963442:oidc-provider/token.actions.githubusercontent.com"

  validation {
    condition     = var.github_oidc_provider_arn == null ? true : can(regex("^arn:[^:]+:iam::[0-9]{12}:oidc-provider/token[.]actions[.]githubusercontent[.]com$", var.github_oidc_provider_arn))
    error_message = "The OIDC provider ARN must identify the GitHub Actions provider."
  }
}

variable "deploy_role_name" {
  description = "IAM role name used by the GitHub Actions deployment."
  type        = string
  default     = "portfolio-deploy-role"
}

variable "enable_request_report" {
  description = "Create the weekly CloudFront request report resources."
  type        = bool
  default     = false
}

variable "request_report_email" {
  description = "SNS email recipient for the weekly request report."
  type        = string
  default     = ""
  sensitive   = true
}