output "cluster_endpoint" {
  value = aws_rds_cluster.main.endpoint
}

output "secret_arn" {
  value = aws_rds_cluster.main.master_user_secret[0].secret_arn
}
