##############################################################
# Terraform: Crypto Streaming Platform Infrastructure
# Author: Jonas
# Description: Fully automated, Zero-Trust network architecture 
# deployed on OCI Always Free Tier. Includes Compute (ARM), 
# Object Storage (Cold Tier), and ADW (Warm Tier) with 
# internal private routing and Resource Principals.
##############################################################

# Fetch the public IP of the machine running Terraform
data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

# Local variable to format the IP as a CIDR block (/32)
locals {
  current_ip = "${chomp(data.http.my_public_ip.response_body)}/32"
}

# -----------------------------
# 1. Virtual Cloud Network (VCN)
# -----------------------------
resource "oci_core_vcn" "streaming_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "vcn-crypto-streaming"
  dns_label      = "cryptovcn"
}

# -----------------------------
# 2. Gateways (Internet & Service)
# -----------------------------
# IGW for public inbound (SSH) and outbound API calls (Binance)
resource "oci_core_internet_gateway" "streaming_ig" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.streaming_vcn.id
  display_name   = "ig-crypto-streaming"
}

# Find the Oracle Services Network CIDR for the Service Gateway
#data "oci_core_services" "all_services" {
#  filter {
#    name   = "name"
#    values = ["All .* Services In Oracle Services Network"]
#    regex  = true
#  }
#}

# SGW allows the VM to securely access Object Storage without going over the public internet (FinOps & Security)
#resource "oci_core_service_gateway" "streaming_sg" {
#  compartment_id = var.compartment_id
#  vcn_id         = oci_core_vcn.streaming_vcn.id
#  display_name   = "sg-crypto-streaming"
#  services {
#    service_id = data.oci_core_services.all_services.services[0].id
#  }
#}

# -----------------------------
# 3. Route Table
# -----------------------------
resource "oci_core_route_table" "streaming_rt" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.streaming_vcn.id
  display_name   = "rt-crypto-streaming"

  # El Internet Gateway manejará tanto el tráfico a Binance como hacia OCI Object Storage
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.streaming_ig.id
  }
}

# -----------------------------
# 4. Security List (Firewall Rules)
# -----------------------------
resource "oci_core_security_list" "streaming_sl" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.streaming_vcn.id
  display_name   = "sl-crypto-streaming"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }
  
  # Allow SSH from your specific public IP
  ingress_security_rules {
    protocol = "6" # TCP
    source   = local.current_ip
    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow internal VCN traffic to ADW port (1522) for VM to Database communication
  ingress_security_rules {
    protocol    = "6"
    source      = oci_core_vcn.streaming_vcn.cidr_block
    description = "Allow internal traffic to ADW Private Endpoint"
    tcp_options {
      min = 1522
      max = 1522
    }
  }
}

# -----------------------------
# 5. Public Subnet
# -----------------------------
resource "oci_core_subnet" "streaming_subnet" {
  compartment_id    = var.compartment_id
  vcn_id            = oci_core_vcn.streaming_vcn.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "public-subnet-crypto"
  route_table_id    = oci_core_route_table.streaming_rt.id
  security_list_ids = [oci_core_security_list.streaming_sl.id]
  dns_label         = "publicsub"
  prohibit_public_ip_on_vnic = false
}

# -----------------------------
# 6. Compute Instance (ARM Ampere)
# -----------------------------
data "oci_core_images" "ubuntu_arm" {
  compartment_id           = var.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
  shape                    = "VM.Standard.A1.Flex" # Updated to ARM shape

  sort_by    = "TIMECREATED"
  sort_order = "DESC"
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

resource "oci_core_instance" "streaming_vm" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_id
  display_name        = "vm-crypto-streaming"
  shape               = "VM.Standard.A1.Flex"

  # Scaled up for Flink & Redpanda (Requires PAYG account for capacity, but remains free tier eligible)
  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.streaming_subnet.id
    assign_public_ip = true
    hostname_label   = "cryptovm"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_arm.images[0].id
    boot_volume_size_in_gbs = 50
  }

  metadata = {
    ssh_authorized_keys = file(var.ssh_public_key_path)
    
    # templatefile reads your .tftpl and replaces the variables before sending it to OCI
    user_data = base64encode(templatefile("${path.module}/cloud-init.tftpl", {
      ocir_region     = var.region                                      # e.g.: "phx" or "iad"
      ocir_namespace  = data.oci_objectstorage_namespace.ns.namespace   # Obtained from OCI automatically
      ocir_username   = var.oci_username                                # Your Oracle Cloud email/username
      ocir_auth_token = var.ocir_auth_token                             # The token generated in the console
    }))
  }

  preserve_boot_volume = false
}

# -----------------------------
# 7. OCI Object Storage (Cold Data)
# -----------------------------
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "crypto_archive_bucket" {
  compartment_id = var.compartment_id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "crypto-streaming-archive"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard" 
}

# -----------------------------
# 8. Autonomous Data Warehouse (Always Free)
# -----------------------------
resource "oci_database_autonomous_database" "crypto_adw" {
  compartment_id           = var.compartment_id
  db_name                  = "cryptoadw"
  display_name             = "adw-crypto-streaming"
  admin_password           = var.adw_admin_password
  db_workload              = "DW"
  
  is_free_tier             = true
  license_model            = "LICENSE_INCLUDED"
  is_mtls_connection_required = false

  # FinOps & Security: To assure the free tier ADW is only accessible from the streaming VM and the user's public IP,
  # we block all internet traffic and only allow:
  # 1. The user's public IP (for DBeaver/SQL Developer)
  # 2. The streaming VM's public IP (for Flink to send data)
  whitelisted_ips          = [
    local.current_ip, 
    oci_core_instance.streaming_vm.public_ip
  ]
}

# -----------------------------
# 9. IAM: Resource Principal (Zero-Trust)
# -----------------------------
# Dynamic group containing the ADW instance. MUST be created at the tenancy level.
resource "oci_identity_dynamic_group" "adw_dg" {
  compartment_id = var.tenancy_ocid
  name           = "dg-crypto-adw"
  description    = "Dynamic group for ADW instance to authenticate without credentials"
  matching_rule  = "ALL {resource.type = 'autonomousdatabase', resource.compartment.id = '${var.compartment_id}'}"
}

# Policy allowing the ADW (via Dynamic Group) to read/write into the Object Storage bucket
resource "oci_identity_policy" "adw_storage_policy" {
  compartment_id = var.compartment_id
  name           = "policy-adw-to-storage"
  description    = "Allow ADW to manage objects in the crypto archive bucket"
  statements     = [
    "Allow dynamic-group ${oci_identity_dynamic_group.adw_dg.name} to manage objects in compartment id ${var.compartment_id} where target.bucket.name='${oci_objectstorage_bucket.crypto_archive_bucket.name}'"
  ]
}

# -----------------------------
# 10. OCI Container Registry (OCIR)
# -----------------------------
# Private repository for Docker images (Python Producer, Flink Jobs, etc.)
resource "oci_artifacts_container_repository" "crypto_repo" {
  compartment_id = var.compartment_id
  display_name   = "crypto-streaming-repo"
  
  # Security best practice: Keep it private
  is_public      = false
  
  # Allow overwriting tags (e.g. 'latest') during development
  is_immutable   = false 
}

# -----------------------------
# 11. FinOps: Budget & Alerts
# -----------------------------
# Define a monthly budget of 1 USD for the specific compartment
resource "oci_budget_budget" "crypto_budget" {
  compartment_id        = var.tenancy_ocid # Budgets are created at the tenancy level
  amount                = 1                # 1 USD limit
  reset_period          = "MONTHLY"
  targets               = [var.compartment_id]
  target_type           = "COMPARTMENT"
  display_name          = "budget-crypto-streaming"
  description           = "Strict 1 USD monthly budget for the crypto platform"
}

# Alert 1: ACTUAL spend reaches 100% of the budget ($1 USD)
resource "oci_budget_alert_rule" "crypto_budget_alert_actual" {
  budget_id      = oci_budget_budget.crypto_budget.id
  threshold      = 100
  threshold_type = "PERCENTAGE"
  type           = "ACTUAL"
  recipients     = var.alert_email
  message        = "FINOPS ALERT: The crypto streaming platform has reached its actual 1 USD monthly budget."
  display_name   = "alert-actual-crypto-budget"
}

# Alert 2: FORECASTED spend is expected to exceed 100% of the budget
resource "oci_budget_alert_rule" "crypto_budget_alert_forecast" {
  budget_id      = oci_budget_budget.crypto_budget.id
  threshold      = 100
  threshold_type = "PERCENTAGE"
  type           = "FORECAST"
  recipients     = var.alert_email
  message        = "FINOPS WARNING: The crypto streaming platform is projected to exceed the 1 USD budget this month."
  display_name   = "alert-forecast-crypto-budget"
}

# -----------------------------
# 12. Outputs
# -----------------------------
output "vm_public_ip" {
  value       = oci_core_instance.streaming_vm.public_ip
  description = "Public IP of the VM (connect directly via SSH)"
}

output "ssh_connection" {
  value       = "ssh -i ~/.ssh/id_ed25519_oci ubuntu@${oci_core_instance.streaming_vm.public_ip}"
  description = "Direct SSH command to VM"
}