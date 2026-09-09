variable "vpc_cidr" {
  type        = string
  description = "IP Rang for the VPC"
}

variable "subnet_cidr" {
  type        = string
  description = "IP Rang for the public subnet"
}

variable "availability_zone" {
  type        = string
  description = "AWS Availability Zone"
}

variable "environment" {
  type        = string
  description = "Env name like dev , staging , prod"
}

variable "subnet_2_cidr" {
  type        = string
  description = "IP Range for the second public subnet (multi-AZ requirement)"
}

variable "subnet_2_availability_zone" {
  type        = string
  description = "AWS Availability Zone for the second public subnet"
}


# #if variable with default value 
# variable "instance_type" {
#   type = string
#   default = "t3.micro"
#   description = "The EC2 server type"
# }

# #if with no default value , (User must provide a value)
# variable "environment" {
#   type = string
#   description = "The environment name"
# }

# #if with no default value , (User must provide a value)
# variable "db_password" {
#   type = string
#   sensitive = true  # don't show the value in the output
#   description = "The database password"
# }
