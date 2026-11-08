variable "aws_region" {
  description = "AWS region used by the portfolio infrastructure and email parameter."
  type        = string
  default     = "ap-southeast-2"
}

variable "github_repository" {
  description = "GitHub owner/repository allowed to assume the workflow roles."
  type        = string
  default     = "KFrost533/infra-s3-portfolio"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository format."
  }
}

variable "github_repository_owner_id" {
  description = "Immutable GitHub owner ID used in the OIDC subject."
  type        = string
  default     = "155362696"
}

variable "github_repository_id" {
  description = "Immutable GitHub repository ID used in the OIDC subject."
  type        = string
  default     = "1441557129"
}

variable "state_bucket_name" {
  description = "Existing S3 bucket that stores both Terraform states."
  type        = string
  default     = "tf-kfrost533"
}

variable "portfolio_bucket_name" {
  description = "S3 bucket managed by terraform/main."
  type        = string
  default     = "kfrost533-portfolio-s3"

  validation {
    condition     = var.portfolio_bucket_name != var.state_bucket_name
    error_message = "The portfolio bucket must not be the Terraform state bucket."
  }
}

variable "hosted_zone_id" {
  description = "Existing Route 53 hosted zone that terraform/main updates."
  type        = string
  default     = ""
}

variable "request_report_email_parameter" {
  description = "Existing SSM parameter name used when the optional report is enabled."
  type        = string
  default     = "mail_address"
}

variable "apply_role_name" {
  description = "Name of the GitHub Actions Terraform apply role."
  type        = string
  default     = "portfolio-terraform-apply"
}

variable "destroy_role_name" {
  description = "Name of the GitHub Actions Terraform destroy role."
  type        = string
  default     = "portfolio-terraform-destroy"
}

variable "deploy_role_name" {
  description = "Name of the portfolio HTML deployment role managed by terraform/main."
  type        = string
  default     = "portfolio-deploy-role"
}

variable "report_function_name" {
  description = "Name prefix for optional weekly report resources."
  type        = string
  default     = "portfolio-weekly-requests"
}
