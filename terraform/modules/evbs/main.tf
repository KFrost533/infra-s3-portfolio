resource "aws_scheduler_schedule" "report" {
  name                         = "portfolio-weekly-requests"
  schedule_expression          = "cron(0 9 ? * MON *)"
  schedule_expression_timezone = "Asia/Tokyo"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = var.function_arn
    role_arn = var.role_arn
    input    = jsonencode({ scheduled_time = "<aws.scheduler.scheduled-time>" })
  }
}
