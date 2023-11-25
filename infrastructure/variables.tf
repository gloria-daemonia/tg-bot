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

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
