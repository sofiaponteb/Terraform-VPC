##############################################################################
# VPC Variables
##############################################################################

variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
}

variable "resource_group_name" {
  description = "ID for IBM Cloud Resource Group"
}

# unique vpc name
variable "unique_id" {
  description = "The vpc unique id"
}