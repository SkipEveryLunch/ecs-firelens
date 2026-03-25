resource "aws_lb_target_group" "api" {
  name                 = "${var.project_name}-api-${var.env}"
  vpc_id               = var.vpc_id
  port                 = 3000
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 3
    interval            = 10
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}
