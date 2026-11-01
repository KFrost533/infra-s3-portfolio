terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_acm_certificate" "portfolio" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "portfolio" {
  certificate_arn         = aws_acm_certificate.portfolio.arn
  validation_record_fqdns = [var.validation_record_fqdn]
}