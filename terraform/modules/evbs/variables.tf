variable "function_arn" {
  description = "Weekly report Lambda ARN."
  type        = string
}

variable "role_arn" {
  description = "EventBridge Scheduler execution role ARN."
  type        = string
}
