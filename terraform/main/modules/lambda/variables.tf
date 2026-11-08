variable "function_name" {
  description = "Name of the weekly request report Lambda."
  type        = string
}

variable "role_arn" {
  description = "Lambda execution role ARN."
  type        = string
}

variable "topic_arn" {
  description = "SNS topic ARN for the request report."
  type        = string
}

variable "distribution_id" {
  description = "CloudFront distribution ID to report."
  type        = string
}
