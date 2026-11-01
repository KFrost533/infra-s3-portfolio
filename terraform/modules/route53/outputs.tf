output "validation_record_fqdn" {
  description = "FQDN of the ACM certificate validation record."
  value       = aws_route53_record.certificate_validation.fqdn
}

output "hosted_zone_name_servers" {
  description = "Name servers to delegate the new hosted zone."
  value       = aws_route53_zone.portfolio.name_servers
}
