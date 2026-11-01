output "validation_record" {
  description = "DNS record required to validate the certificate."
  value       = one(aws_acm_certificate.portfolio.domain_validation_options)
}

output "validated_certificate_arn" {
  description = "ARN of the validated CloudFront certificate."
  value       = aws_acm_certificate_validation.portfolio.certificate_arn
}
