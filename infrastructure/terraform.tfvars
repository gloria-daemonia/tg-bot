region   = "eu-north-1"
env_name = "prd01"
tags     = { "env" : "prd01" }

#VPC
vpc_cidr               = "10.10.0.0/16"
vpc_public_subnets     = ["10.10.0.0/24", "10.10.1.0/24", "10.10.2.0/24"]
auto_assign_public_ip  = true
vpc_private_subnets    = ["10.10.3.0/24", "10.10.4.0/24", "10.10.5.0/24"]
vpc_database_subnets   = ["10.10.6.0/24", "10.10.7.0/24", "10.10.8.0/24"]
vpc_enable_nat_gateway = false
vpc_single_nat_gateway = false
