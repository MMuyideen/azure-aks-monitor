variable "rgname" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type    = string
  default = "eastus"
}

variable "service_principal_name" {
  type = string
}

variable "keyvault_name" {
  type = string
}