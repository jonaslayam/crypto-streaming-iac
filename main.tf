##############################################################
# Terraform: Crypto Streaming Platform Infrastructure
# Author: Jonas
# Description: Fully automated Cloud-Native architecture 
# deployed on OCI Always Free Tier. Features an ARM-based 
# Compute instance, Autonomous Data Warehouse (ADW) with 
# Network ACLs, and Object Storage secured via Resource 
# Principals for a Zero-Trust identity-based access model.
##############################################################

# Fetch the public IP of the machine running Terraform
data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

# Local variable to format the IP as a CIDR block (/32)
locals {
  current_ip = "${chomp(data.http.my_public_ip.response_body)}/32"
}

# OCI Container Registry (OCIR)

# Private repository for Docker images (Python Producer, Flink Jobs, etc.)
resource "oci_artifacts_container_repository" "crypto_repo" {
  compartment_id = var.compartment_id
  display_name   = "crypto-streaming-repo"
  
  # Security best practice: Keep it private
  is_public      = false
  
  # Allow overwriting tags (e.g. 'latest') during development
  is_immutable   = false 
}

# Outputs

output "vm_public_ip" {
  value       = oci_core_instance.streaming_vm.public_ip
  description = "Public IP of the VM (connect directly via SSH)"
}

output "ssh_connection" {
  value       = "ssh -i ~/.ssh/id_ed25519_oci ubuntu@${oci_core_instance.streaming_vm.public_ip}"
  description = "Direct SSH command to VM"
}