resource "aws_route53_zone" "portfolio" {
  name = var.hosted_zone_name

  lifecycle {
    precondition {
      condition     = var.domain_name == var.hosted_zone_name || endswith(var.domain_name, ".${var.hosted_zone_name}")
      error_message = "Set hosted_zone_name to a DNS domain that matches domain_name or is its parent domain; it must not be a descriptive label."
    }
  }
}

resource "aws_route53_record" "certificate_validation" {
  zone_id = aws_route53_zone.portfolio.zone_id
  name    = var.certificate_validation.resource_record_name
  type    = var.certificate_validation.resource_record_type
  records = [var.certificate_validation.resource_record_value]
  ttl     = 60
}

resource "aws_route53_record" "portfolio" {
  for_each = toset(["A", "AAAA"])

  zone_id = aws_route53_zone.portfolio.zone_id
  name    = var.domain_name
  type    = each.value

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}