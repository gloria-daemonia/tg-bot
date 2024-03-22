region   = "eu-north-1"
env_name = "prd02"
tags     = { "env" : "prd02" }

#VPC
vpc_cidr               = "10.11.0.0/16"
vpc_public_subnets     = ["10.11.0.0/24", "10.11.1.0/24", "10.11.2.0/24"]
auto_assign_public_ip  = true
vpc_private_subnets    = ["10.11.3.0/24", "10.11.4.0/24", "10.11.5.0/24"]
vpc_database_subnets   = ["10.11.6.0/24", "10.11.7.0/24", "10.11.8.0/24"]
vpc_enable_nat_gateway = false
vpc_single_nat_gateway = false
