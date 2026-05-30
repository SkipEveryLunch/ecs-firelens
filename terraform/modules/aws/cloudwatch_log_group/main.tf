resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project_name}-api-${var.env}"
  retention_in_days = var.retention_in_days
}

resource "aws_cloudwatch_log_group" "db_migrator" {
  name              = "/ecs/${var.project_name}-db-migrator-${var.env}"
  retention_in_days = var.retention_in_days
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.project_name}-worker-${var.env}"
  retention_in_days = var.retention_in_days
}

resource "aws_cloudwatch_log_group" "log_router" {
  name              = "/ecs/${var.project_name}-log-router-${var.env}"
  retention_in_days = var.retention_in_days
}
