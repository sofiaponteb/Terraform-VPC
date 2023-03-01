##############################################################################
# Bastion host output variables. 
#
# Ouputs required as input to SG and Subnet configs that require bastion access 
##############################################################################


# public (floating) IP address attached to the bastion hosts. Ordered by zone attachment. 
output "bastion_ip_addresses" {
  value = ibm_is_floating_ip.bastion.*.address
}

# Allocated bastion subnets. 
output "bastion_subnet_ids" {
  value = ibm_is_subnet.bastion_subnet.*.id
}
