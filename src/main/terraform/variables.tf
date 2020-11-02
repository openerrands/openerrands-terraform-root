variable "global_prefix" {
  type = string
  default = "openerrands"
}

variable "region" {
  type = string
  default = "us-east-2"
}

variable "environments" {
  type = list(string)
  default = ["dev", "prod"]
}

variable "secrets" {
  type = bool
  default = false
}