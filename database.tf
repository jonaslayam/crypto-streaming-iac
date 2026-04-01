# Autonomous Data Warehouse (Always Free)

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