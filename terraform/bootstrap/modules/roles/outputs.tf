output "apply_role_arn" {
  value = aws_iam_role.apply.arn
}

output "destroy_role_arn" {
  value = aws_iam_role.destroy.arn
}
