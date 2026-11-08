variable "domain_name" {
  description = "Public domain name for the certificate."
  type        = string
}

variable "validation_record_fqdn" {
  description = "DNS validation record FQDN."
  type        = string
}
