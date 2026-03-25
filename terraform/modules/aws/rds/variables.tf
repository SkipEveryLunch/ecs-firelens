variable "project_name" {}

variable "env" {}

variable "security_group_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "db_name" {
  default = "app"
}

variable "rds" {
  type = object({
    min_capacity = number
    max_capacity = number
  })
  default = {
    min_capacity = 0.5
    max_capacity = 4.0
  }
}
