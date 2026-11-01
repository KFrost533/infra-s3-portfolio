output "distribution_arn" {
  description = "Distribution ARN used by the S3 bucket policy."
  value       = aws_cloudfront_distribution.portfolio.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.portfolio.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront hosted zone ID used for Route 53 aliases."
  value       = aws_cloudfront_distribution.portfolio.hosted_zone_id
}
