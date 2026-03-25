output "arn_ecs_task_execution" {
  value = aws_iam_role.ecs_task_execution.arn
}

output "arn_ecs_task" {
  value = aws_iam_role.ecs_task.arn
}

output "arn_github_actions" {
  value = aws_iam_role.github_actions.arn
}
