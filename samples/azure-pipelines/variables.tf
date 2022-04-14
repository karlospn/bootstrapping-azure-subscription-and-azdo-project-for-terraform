variable "project_name" {
    description = "The name of the project"
    type        = string
    default     = "myproject"
}

variable "environment" {
    description ="The environment name. Possible values are dev and pro"
    type = string
    default = "dev"
}

variable "location" {
    description = "Location where the resources are going to be deployed"
    type        = string
    default     = "West Europe"
}

variable "default_tags" {
  type    = map(string)
  description = "Default tags to be applied"
  default = {
    "region" = "west europe"
    "environment" = "dev"
    "business-unit" = "It"
    "workload-name": "myproject"
    "owner-name": "someone@mytechramblings.com"
    "technical-contact" : "other@mytechramblings.com"
    "scope" : "private"
    "active-period" : "24/7"
    "customer" : "Customer1"
    "priority" : "L1"
  } 
}

