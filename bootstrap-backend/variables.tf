variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "account_id" {
  type    = string
  default = "888696596070"
}

variable "bucket_name" {
  type    = string
  default = "terraform-assessment-bucket"
}

variable "dynamodb_table_name" {
  type    = string
  default = "terraform-locks"
}

variable "aws_profile" {
  type    = string
  default = "terraform-admin"
}