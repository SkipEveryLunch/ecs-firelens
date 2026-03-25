output "name_api" {
  value = aws_cloudwatch_log_group.api.name
}

output "name_db_migrator" {
  value = aws_cloudwatch_log_group.db_migrator.name
}

output "name_worker" {
  value = aws_cloudwatch_log_group.worker.name
}
