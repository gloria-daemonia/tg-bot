variable "region" {
  type        = string
  description = "Region name. Example: 'eu-north-1'"
  nullable    = false
}

variable "env_name" {
  description = "The environment name. Format: {3}[a-z]{2}[0-9]. For example 'dev01'"
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z][a-z][0-9][0-9]$", var.env_name))
    error_message = "The env name should fit the follwing format: {3}[a-z]{2}[0-9]."
  }
}

variable "api_key" {
  description = "Telegram bot API key"
  type        = string
  nullable    = false
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}


#VPC vars
variable "vpc_cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.10.0.0/16"
  nullable    = false
}
variable "vpc_public_subnets" {
  description = "A list of public subnets CIDRs inside the VPC"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  nullable    = false
}
variable "vpc_private_subnets" {
  description = "A list of private subnets CIDRs inside the VPC"
  type        = list(string)
  default     = ["10.10.3.0/24", "10.10.4.0/24", "10.10.5.0/24"]
  nullable    = false
}
variable "vpc_database_subnets" {
  description = "A list of database subnets CIDRs inside the VPC"
  type        = list(string)
  default     = ["10.10.6.0/24", "10.10.7.0/24", "10.10.8.0/24"]
  nullable    = false
}
variable "vpc_enable_nat_gateway" {
  description = "Whether to create NAT Gateways (one or more)."
  type        = bool
  default     = false
  nullable    = false
}
variable "vpc_single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks. This will not work if var.vpc_enable_nat_gateway == false."
  type        = bool
  default     = false
  nullable    = false
}

