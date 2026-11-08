variable "bucket_name" {
  description = "Globally unique S3 bucket name for the portfolio."
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "CloudFront distribution permitted to read the bucket."
  type        = string
}
