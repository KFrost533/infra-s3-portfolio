output "validation_record_fqdn" {
  description = "FQDN of the ACM certificate validation record."
  value       = aws_route53_record.certificate_validation.fqdn
}

output "hosted_zone_id" {
  description = "ID of the existing public hosted zone receiving portfolio records."
  value       = var.hosted_zone_id
}
