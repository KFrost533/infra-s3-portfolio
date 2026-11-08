output "bucket_name" {
  description = "Portfolio bucket name."
  value       = aws_s3_bucket.portfolio.id
}

output "bucket_arn" {
  description = "Portfolio bucket ARN."
  value       = aws_s3_bucket.portfolio.arn
}

output "bucket_regional_domain" {
  description = "Regional S3 domain name for the CloudFront origin."
  value       = aws_s3_bucket.portfolio.bucket_regional_domain_name
}
