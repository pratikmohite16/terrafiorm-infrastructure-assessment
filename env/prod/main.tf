terraform {
  backend "s3" {}
}

locals {
  name = "prod"
  tags = {
    Project = var.project_name
    Env     = local.name
    Owner   = var.owner
    Criticality = "High"
  }
}

module "vpc" {
  source = "../../modules/vpc"
  name   = local.name
  cidr   = var.vpc_cidr
  azs    = var.azs
  tags   = local.tags
}

module "sg" {
  source               = "../../modules/security_groups"
  name                 = local.name
  vpc_id               = module.vpc.vpc_id
  allowed_admin_cidrs  = var.allowed_admin_cidrs
  tags                 = local.tags
}

data "aws_kms_key" "default" {
  key_id = "alias/aws/rds"
}

data "aws_iam_role" "rds_emr" {
  name = "rds-monitoring-role"
}

# -------------------------
# RDS Databases (HIGH AVAILABILITY)
# -------------------------
module "rds_otc" {
  source                    = "../../modules/rds_postgres"
  name                      = "${local.name}-otc"
  pg_family                 = "postgres16"
  engine_version            = "16.3"
  instance_class            = "db.m6g.large"
  allocated_storage         = 100
  private_subnet_ids        = module.vpc.private_subnet_ids
  rds_sg_id                 = module.sg.sg_rds_id
  kms_key_id                = data.aws_kms_key.default.arn
  multi_az                  = true
  backup_retention_days     = 14
  deletion_protection       = true
  enhanced_monitoring_role_arn = data.aws_iam_role.rds_emr.arn
  tags                      = local.tags
}

module "rds_gps" {
  source                    = "../../modules/rds_postgres"
  name                      = "${local.name}-gps"
  pg_family                 = "postgres16"
  engine_version            = "16.3"
  instance_class            = "db.m6g.large"
  allocated_storage         = 100
  private_subnet_ids        = module.vpc.private_subnet_ids
  rds_sg_id                 = module.sg.sg_rds_id
  kms_key_id                = data.aws_kms_key.default.arn
  multi_az                  = true
  backup_retention_days     = 14
  deletion_protection       = true
  enhanced_monitoring_role_arn = data.aws_iam_role.rds_emr.arn
  tags                      = local.tags
}

module "rds_arp" {
  source                    = "../../modules/rds_postgres"
  name                      = "${local.name}-arp"
  pg_family                 = "postgres16"
  engine_version            = "16.3"
  instance_class            = "db.m6g.large"
  allocated_storage         = 200
  private_subnet_ids        = module.vpc.private_subnet_ids
  rds_sg_id                 = module.sg.sg_rds_id
  kms_key_id                = data.aws_kms_key.default.arn
  multi_az                  = true
  backup_retention_days     = 14
  deletion_protection       = true
  enhanced_monitoring_role_arn = data.aws_iam_role.rds_emr.arn
  tags                      = local.tags
}

# -------------------------
# Bastion
# -------------------------
module "bastion" {
  source           = "../../modules/bastion"
  name             = local.name
  instance_type    = "t3.medium"
  public_subnet_id = module.vpc.public_subnet_ids[0]
  sg_bastion_id    = module.sg.sg_bastion_id
  tags             = local.tags
}

# -------------------------
# Grafana
# -------------------------
variable "grafana_cert_arn" { type = string }

module "grafana" {
  source             = "../../modules/grafana_ec2_alb"
  name               = local.name
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  sg_alb_id          = module.sg.sg_alb_id
  sg_grafana_id      = module.sg.sg_grafana_id
  acm_arn            = var.grafana_cert_arn
  instance_type      = "t3.medium"
  tags               = local.tags
}

# -------------------------
# GitHub OIDC Role
# -------------------------
module "gha_oidc" {
  source        = "../../modules/iam_github_oidc"
  name          = "${local.name}-gha"
  allowed_repos = ["repo:yourorg/aws-db-platform:*"]
}

# -------------------------
# Outputs
# -------------------------
output "rds_endpoints" {
  value = {
    otc = module.rds_otc.endpoint
    gps = module.rds_gps.endpoint
    arp = module.rds_arp.endpoint
  }
}

output "grafana_url" {
  value = module.grafana.grafana_alb_dns
}

output "gha_role_arn" {
  value = module.gha_oidc.role_arn
}
