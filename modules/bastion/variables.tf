variable "name" { type = string }
variable "instance_type" { type = string default = "t3.micro" }
variable "public_subnet_id" { type = string }
variable "sg_bastion_id" { type = string }
variable "tags" { type = map(string) default = {} }
