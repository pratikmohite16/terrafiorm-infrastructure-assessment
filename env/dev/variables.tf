variable "project_name" { type = string }
variable "owner" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "allowed_admin_cidrs" { type = list(string) }
variable "grafana_cert_arn" { type = string }
