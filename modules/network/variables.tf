variable "name" { type = string }
variable "cidr_block" { type = string }
variable "az_count" { type = number }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "enable_nat" { type = bool }
variable "tags" { type = map(string) }
