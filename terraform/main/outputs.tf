output "bucket_name" {
  description = "Bucket name for the PORTFOLIO_BUCKET GitHub Actions variable."
  value       = module.s3.bucket_name
}

output "aws_region" {
  description = "Region for the AWS_REGION GitHub Actions variable."
  value       = var.aws_region
}

output "deploy_role_arn" {
  description = "Role ARN for the AWS_ROLE_ARN GitHub Actions variable."
  value       = module.iam.deploy_role_arn
}

output "portfolio_url" {
  description = "Public HTTPS URL for the portfolio main page."
  value       = "https://${var.domain_name}/"
}

output "cloudfront_url" {
  description = "CloudFront distribution HTTPS URL."
  value       = "https://${module.cloudfront.distribution_domain_name}/"
}

output "cloudfront_distribution_id" {
  description = "Distribution ID for the CLOUDFRONT_DISTRIBUTION_ID GitHub Actions variable."
  value       = module.cloudfront.distribution_id
}

output "hosted_zone_name_servers" {
  description = "Name servers to delegate the new hosted zone."
  value       = module.route53.hosted_zone_name_servers
}

output "request_report_topic_arn" {
  description = "SNS topic ARN for the optional weekly request report."
  value       = var.enable_request_report ? module.sns[0].topic_arn : null
}
