variable "project_name" {}

variable "env" {}

variable "name" {
  default = ""
}

variable "retained_image_count" {
  type    = number
  default = 10
}
