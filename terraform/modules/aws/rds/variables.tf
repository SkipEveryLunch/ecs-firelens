variable "project_name" {}

variable "env" {}

variable "security_group_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "db_name" {
  default = "app"
}

variable "instance_class" {
  default = "db.t4g.micro"
}
