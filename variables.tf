
variable "web_app" {
  default = "mywebapp"
}

variable "web_instance_type" {
  default = "t2.micro"
}

variable "web_max_size" {
  default = 3
}

variable "web_min_size" {
  default = 1
}

variable "web_desired_capacity" {
  default = 2
}

variable "web_key_name" {
  default = "avilashkp"
}
