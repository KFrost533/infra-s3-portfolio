output "topic_arn" {
  description = "SNS topic ARN for weekly reports."
  value       = aws_sns_topic.report.arn
}
