resource "random_password" "db" {
  length  = 20
  special = true
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_secretsmanager_secret" "db_master" {
  name = "${var.name}/db/master"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_master_v" {
  secret_id     = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({ username = var.master_username, password = random_password.db.result })
}

resource "aws_db_parameter_group" "pg" {
  name   = "${var.name}-pg"
  family = var.pg_family # e.g., "postgres16"
  tags   = var.tags
}

resource "aws_db_instance" "this" {
  identifier              = var.name
  engine                  = "postgres"
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  allocated_storage       = var.allocated_storage
  storage_encrypted       = true
  kms_key_id              = var.kms_key_id
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.rds_sg_id]
  multi_az                = var.multi_az
  username                = var.master_username
  password                = random_password.db.result
  skip_final_snapshot     = false
  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.deletion_protection
  parameter_group_name    = aws_db_parameter_group.pg.name
  monitoring_interval     = 60
  monitoring_role_arn     = var.enhanced_monitoring_role_arn
  tags = merge(var.tags, { DBName = var.name })
}

output "endpoint" { value = aws_db_instance.this.address }
output "secret_arn" { value = aws_secretsmanager_secret.db_master.arn }
