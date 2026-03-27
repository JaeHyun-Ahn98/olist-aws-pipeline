variable "aws_region" {
  default = "ap-northeast-2"
}

variable "project_name" {
  default = "olist-pipeline"
}

variable "account_id" {
  description = "AWS Account ID"
}

variable "redshift_username" {
  description = "Redshift 마스터 유저명"
}

variable "redshift_password" {
  description = "Redshift 마스터 비밀번호"
  sensitive   = true
}