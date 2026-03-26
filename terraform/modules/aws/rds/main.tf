resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.env}"
  description = "Managed by Terraform"
  subnet_ids  = var.subnet_ids
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-${var.env}"
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class
  db_name        = var.db_name

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]

  username                    = "postgres"
  manage_master_user_password = true

  storage_type      = "gp3"
  allocated_storage = 20
  storage_encrypted = true

  skip_final_snapshot = true
}
