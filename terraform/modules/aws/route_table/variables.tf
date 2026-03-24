variable "project_name" {}

variable "env" {}

variable "vpc_id" {}

variable "internet_gateway_id" {}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}
