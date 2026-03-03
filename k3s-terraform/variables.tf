variable "region" {
  type    = string
  default = "ap-northeast-2" # 서울 리전
}

variable "project_name" {
  type    = string
  default = "k3s-paas-portfolio"
}

variable "my_ip_cidr" {
  type        = string
  description = "125.139.127.14/32"
}

variable "key_name" {
  type        = string
  description = "prj-pemkey.pem"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "root_volume_size" {
  type    = number
  default = 20
}
variable "github_token" {
  type      = string
  sensitive = true
}
