variable "hosted_zone_id" {
  description = "ID of the existing public Route 53 hosted zone."
  type        = string
}

variable "domain_name" {
  description = "Public domain name for the portfolio."
  type        = string
}

variable "certificate_validation" {
  description = "DNS record details supplied by ACM."
  type = object({
    resource_record_name  = string
    resource_record_type  = string
    resource_record_value = string
  })
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for alias records."
  type        = string
}
