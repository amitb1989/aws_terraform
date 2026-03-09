variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "admin_role_arn" {
  type    = string
  default = "arn:aws:iam::888696596070:role/AWSReservedSSO_AdministratorAccess_0ef322e71318c003"
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.0.0.0/24",
    "10.0.1.0/24"
  ]
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.0.10.0/24",
    "10.0.11.0/24"
  ]
}

variable "extra_tags" {
  type = map(string)
  default = {
    Owner  = "AmitBapodara"
    Source = "Terraform"
    Env    = "dev"
  }
}