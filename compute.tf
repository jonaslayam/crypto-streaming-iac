# Compute Instance (ARM Ampere)

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
    user_data = base64encode(templatefile("${path.module}/templates/cloud-init.tftpl", {
      ocir_region     = var.region                                      # e.g.: "phx" or "iad"
      ocir_namespace  = data.oci_objectstorage_namespace.ns.namespace   # Obtained from OCI automatically
      ocir_username   = var.oci_username                                # Your Oracle Cloud email/username
      ocir_auth_token = var.ocir_auth_token                             # The token generated in the console
    }))
  }

  preserve_boot_volume = false
}