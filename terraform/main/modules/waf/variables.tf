variable "enable_waf" {
  description = "Enable WAF"
  type        = bool
  default     = true
}

variable "web_acl_arn" {
  description = "ARN of the WAF web ACL"
  type        = string
  default     = ""
}