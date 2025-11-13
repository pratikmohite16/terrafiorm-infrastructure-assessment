data "aws_ami" "al2" {
  most_recent = true
  owners      = ["137112412989"]
  filter { name = "name" values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"] }
}

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.al2.id
  instance_type          = var.instance_type
  subnet_id              = element(var.private_subnet_ids, 0)
  vpc_security_group_ids = [var.sg_grafana_id]
  user_data              = file("${path.module}/userdata.sh")
  iam_instance_profile   = aws_iam_instance_profile.cw.name
  tags = merge(var.tags, { Name = "${var.name}-grafana" })
}

resource "aws_iam_role" "cw" {
  name               = "${var.name}-grafana-cw"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}
data "aws_iam_policy_document" "ec2_assume" {
  statement { actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] } }
}
resource "aws_iam_role_policy_attachment" "cw_readonly" {
  role       = aws_iam_role.cw.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}
resource "aws_iam_instance_profile" "cw" { name = "${var.name}-grafana-ip"; role = aws_iam_role.cw.name }

# ALB + TG + Listener
resource "aws_lb" "alb" {
  name               = "${var.name}-grafana-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [var.sg_alb_id]
  tags               = var.tags
}

resource "aws_lb_target_group" "tg" {
  name     = "${var.name}-grafana-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  health_check { path = "/login" matcher = "200-399" }
  tags = var.tags
}

resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.grafana.id
  port             = 3000
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_arn
  default_action { type = "forward" target_group_arn = aws_lb_target_group.tg.arn }
}

output "grafana_alb_dns" { value = aws_lb.alb.dns_name }
