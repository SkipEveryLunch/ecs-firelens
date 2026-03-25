resource "aws_rds_cluster_parameter_group" "main" {
  name        = "${var.project_name}-${var.env}"
  description = "Managed by Terraform"
  family      = "aurora-postgresql16"
}

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.env}"
  description = "Managed by Terraform"
  subnet_ids  = var.subnet_ids
}

resource "aws_rds_cluster" "main" {
  cluster_identifier              = "${var.project_name}-${var.env}"
  engine                          = "aurora-postgresql"
  // MEMO: Serverless v2 は engine_mode = "serverless" ではなく "provisioned"
  engine_mode                     = "provisioned"
  engine_version                  = "16.4"
  database_name                   = var.db_name
  db_subnet_group_name            = aws_db_subnet_group.main.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name
  vpc_security_group_ids          = [var.security_group_id]
  skip_final_snapshot             = true
  storage_encrypted               = true
  master_username             = "postgres"
  manage_master_user_password = true

  serverlessv2_scaling_configuration {
    min_capacity = var.rds.min_capacity
    max_capacity = var.rds.max_capacity
  }
}

resource "aws_rds_cluster_instance" "main" {
  identifier         = "${var.project_name}-${var.env}"
  cluster_identifier = aws_rds_cluster.main.id
  // MEMO: Serverless v2専用のインスタンスクラス
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version
}
