variable "enable_request_report" {
  description = "Whether to create the request reporting roles."
  type        = bool
}

variable "report_topic_arn" {
  description = "SNS topic ARN for the request report, or null when disabled."
  type        = string
}

variable "report_function_name" {
  description = "Name of the request reporting Lambda function."
  type        = string
}

variable "aws_region" {
  description = "Region hosting the request reporting Lambda and SNS topic."
  type        = string
}
