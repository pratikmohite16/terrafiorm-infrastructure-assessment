provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "Default AWS region"
  default     = "me-central-1"
}
