variable "region" {
  description = "AWS region"
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name prefix"
  default     = "abhi-ejaz"
}

variable "env" {
  description = "Environment"
  default     = "prod"
}

variable "db_username" {
  description = "MariaDB master username"
  default     = "abhi_ejaz"
  sensitive   = true
}

variable "db_password" {
  description = "MariaDB master password"
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  default     = "abhi_ejaz_shop"
}

variable "node_instance_type" {
  description = "EKS node instance type"
  default     = "t3.small"
}

variable "node_min" {
  default = 1
}

variable "node_max" {
  default = 5
}

variable "node_desired" {
  default = 1
}
