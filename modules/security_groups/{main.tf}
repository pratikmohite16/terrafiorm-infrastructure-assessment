resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Bastion SG"
  vpc_id      = var.vpc_id

  ingress { from_port = 22 to_port = 22 protocol = "tcp" cidr_blocks = var.allowed_admin_cidrs }
  egress  { from_port = 0  to_port = 0  protocol = "-1"   cidr_blocks = ["0.0.0.0/0"] }

  tags = var.tags
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds-sg"
  description = "RDS SG"
  vpc_id      = var.vpc_id

  # Allow from bastion only
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress { from_port = 0 to_port = 0 protocol = "-1" cidr_blocks = ["0.0.0.0/0"] }

  tags = var.tags
}

resource "aws_security_group" "alb" {
  name   = "${var.name}-alb-sg"
  vpc_id = var.vpc_id

  ingress { from_port = 443 to_port = 443 protocol = "tcp" cidr_blocks = var.allowed_admin_cidrs }
  egress  { from_port = 0   to_port = 0   protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

resource "aws_security_group" "grafana" {
  name   = "${var.name}-grafana-sg"
  vpc_id = var.vpc_id

  ingress { from_port = 3000 to_port = 3000 protocol = "tcp" security_groups = [aws_security_group.alb.id] }
  egress  { from_port = 0    to_port = 0    protocol = "-1"   cidr_blocks = ["0.0.0.0/0"] }
  tags = var.tags
}

output "sg_bastion_id" { value = aws_security_group.bastion.id }
output "sg_rds_id"     { value = aws_security_group.rds.id }
output "sg_alb_id"     { value = aws_security_group.alb.id }
output "sg_grafana_id" { value = aws_security_group.grafana.id }
