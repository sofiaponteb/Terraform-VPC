
terraform {
  required_version = ">= 1.0.0, < 2.0.0"
  required_providers {
    ibm = {
      source  = "IBM-Cloud/ibm"
      version = "~> 1.33.0"
    }
  }
}

# provider block required with Schematics to set VPC region
provider "ibm" {
  region = var.ibm_region
  #ibmcloud_api_key = var.ibmcloud_api_key
}

data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

data "external" "env" { program = ["jq", "-n", "env"] }
locals {
  region = lookup(data.external.env.result, "TF_VAR_SCHEMATICSLOCATION", "")
  geo    = substr(local.region, 0, 2)
  schematics_ssh_access_map = {
    us = ["169.32.0.0/11", "150.238.0.0/16"],
    eu = ["158.175.0.0/16", "158.176.0.0/15", "141.125.75.80/28", "161.156.139.192/28", "149.81.103.128/28"],

  }
  schematics_ssh_access = lookup(local.schematics_ssh_access_map, local.geo, ["0.0.0.0/0"])
  bastion_ingress_cidr  = var.ssh_source_cidr_override[0] != "0.0.0.0/0" ? var.ssh_source_cidr_override : local.schematics_ssh_access
}


module "vpc" {
  source               = "./vpc"
  ibm_region           = var.ibm_region
  resource_group_name  = var.resource_group_name
  unique_id            = var.vpc_name
}

locals {
  # bastion_cidr_blocks  = [cidrsubnet(var.bastion_cidr, 4, 0), cidrsubnet(var.bastion_cidr, 4, 2), cidrsubnet(var.bastion_cidr, 4, 4)]
  frontend_cidr_blocks = [cidrsubnet(var.frontend_cidr, 4, 0), cidrsubnet(var.frontend_cidr, 4, 2), cidrsubnet(var.frontend_cidr, 4, 4)]
  backend_cidr_blocks  = [cidrsubnet(var.backend_cidr, 4, 0), cidrsubnet(var.backend_cidr, 4, 2), cidrsubnet(var.backend_cidr, 4, 4)]
}


# Create single zone bastion
module "bastion" {
  source                   = "./bastionmodule"
  ibm_region               = var.ibm_region
  bastion_count            = 1
  unique_id                = var.vpc_name
  ibm_is_vpc_id            = module.vpc.vpc_id
  ibm_is_resource_group_id = data.ibm_resource_group.all_rg.id
  bastion_cidr             = var.bastion_cidr
  ssh_source_cidr_blocks   = local.bastion_ingress_cidr
  destination_cidr_blocks  = [var.frontend_cidr, var.backend_cidr]
  destination_sgs          = [module.frontend.security_group_id, module.backend.security_group_id]
  # destination_sg          = [module.frontend.security_group_id, module.backend.security_group_id]
  # vsi_profile             = "cx2-2x4"
  # image_name              = "ibm-centos-7-6-minimal-amd64-1"
  ssh_key_id = data.ibm_is_ssh_key.sshkey.id

}


module "accesscheck" {
  source          = "./accesscheck"
  ssh_accesscheck = var.ssh_accesscheck
  ssh_private_key = var.ssh_private_key
  bastion_host    = module.bastion.bastion_ip_addresses[0]
  target_hosts    = concat(module.frontend.primary_ipv4_address, module.backend.primary_ipv4_address)
}