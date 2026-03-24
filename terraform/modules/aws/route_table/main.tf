resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }

  tags = {
    Name = "${var.project_name}-rtb-public-${var.env}"
  }
}

resource "aws_route_table_association" "public_1a" {
  route_table_id = aws_route_table.public.id
  subnet_id      = var.public_subnet_ids[0]
}

resource "aws_route_table_association" "public_1c" {
  route_table_id = aws_route_table.public.id
  subnet_id      = var.public_subnet_ids[1]
}

resource "aws_route_table" "private" {
  vpc_id = var.vpc_id

  // MEMO: NAT Gatewayなし。プライベートサブネットはRDS専用（ローカルルートのみ）

  tags = {
    Name = "${var.project_name}-rtb-private-${var.env}"
  }
}

resource "aws_route_table_association" "private_1a" {
  route_table_id = aws_route_table.private.id
  subnet_id      = var.private_subnet_ids[0]
}

resource "aws_route_table_association" "private_1c" {
  route_table_id = aws_route_table.private.id
  subnet_id      = var.private_subnet_ids[1]
}
