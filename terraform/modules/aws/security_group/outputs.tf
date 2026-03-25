output "id_alb" {
  value = aws_security_group.alb.id
}

output "id_ecs" {
  value = aws_security_group.ecs.id
}

output "id_rds" {
  value = aws_security_group.rds.id
}
