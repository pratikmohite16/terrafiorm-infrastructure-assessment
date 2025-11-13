variable "name" { type = string }
variable "pg_family" { type = string }
variable "engine_version" { type = string }
variable "instance_class" { type = string }
variable "allocated_storage" { type = number }
variable "private_subnet_ids" { type = list(string) }
variable "rds_sg_id" { type = string }
variable "kms_key_id" { type = string }
variable "multi_az" { type = bool }
variable "backup_retention_days" { type = number }
variable "deletion_protection" { type = bool }
variable "enhanced_monitoring_role_arn" { type = string }
variable "master_username" { type = string default = "masteruser" }
variable "tags" { type = map(string) default = {} }
