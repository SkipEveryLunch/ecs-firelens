resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-${var.env}"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id
  ingress = [
    {
      description      = ""
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 80
      to_port          = 80
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
    },
    {
      description      = ""
      cidr_blocks      = ["0.0.0.0/0"]
      from_port        = 443
      to_port          = 443
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
    },
  ]
  egress = local.default_egress
  tags = {
    Name = "${var.project_name}-alb-${var.env}"
  }
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-${var.env}"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id
  ingress = [
    {
      description      = ""
      cidr_blocks      = []
      from_port        = 3000
      to_port          = 3000
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = [aws_security_group.alb.id]
      self             = false
    },
  ]
  egress = local.default_egress
  tags = {
    Name = "${var.project_name}-ecs-${var.env}"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-${var.env}"
  description = "Managed by Terraform"
  vpc_id      = var.vpc_id
  ingress = [
    {
      description      = ""
      cidr_blocks      = []
      from_port        = 5432
      to_port          = 5432
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = [aws_security_group.ecs.id]
      self             = false
    },
  ]
  egress = local.default_egress
  tags = {
    Name = "${var.project_name}-rds-${var.env}"
  }
}
