resource "aws_sns_topic" "report" {
  name = "portfolio-weekly-requests"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.report.arn
  protocol  = "email"
  endpoint  = var.email_address

  lifecycle {
    precondition {
      condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.email_address))
      error_message = "Set request_report_email to a valid email address before enabling the request report."
    }
  }
}
