resource "aws_internet_gateway" "main" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.project_name}-igw-${var.env}"
  }
}
