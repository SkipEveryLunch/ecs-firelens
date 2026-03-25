variable "project_name" {}

variable "env" {}

variable "security_group_id" {}

variable "subnet_ids" {
  type = list(string)
}

variable "certificate_arn" {}

variable "target_group_arn" {}
