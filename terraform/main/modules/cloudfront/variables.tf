variable "bucket_name" {
  description = "Portfolio bucket name used in the origin access control name."
  type        = string
}

variable "bucket_regional_domain" {
  description = "Regional S3 domain name for the origin."
  type        = string
}

variable "certificate_arn" {
  description = "ARN of the validated CloudFront certificate."
  type        = string
}

variable "domain_name" {
  description = "Public domain name for the portfolio."
  type        = string
}

variable "web_acl_arn" {
  description = "Optional CloudFront-scoped AWS WAF web ACL ARN."
  type        = string
}
