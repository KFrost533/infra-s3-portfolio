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
  value       = module.iam_publish.deploy_role_arn
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

output "waf_web_acl_arn" {
  description = "ARN of the optional CloudFront WAF web ACL."
  value       = var.enable_waf ? module.waf[0].web_acl_arn : null
}

output "hosted_zone_id" {
  description = "Existing Route 53 hosted zone receiving the portfolio DNS records."
  value       = module.route53.hosted_zone_id
}

output "request_report_topic_arn" {
  description = "SNS topic ARN for the optional weekly request report."
  value       = var.enable_request_report ? module.sns[0].topic_arn : null
}
