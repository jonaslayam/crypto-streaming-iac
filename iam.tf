# IAM: Resource Principal (Zero-Trust)

# Dynamic group containing the ADW instance. MUST be created at the tenancy level.
resource "oci_identity_dynamic_group" "adw_dg" {
  provider       = oci.home
  compartment_id = var.tenancy_ocid
  name           = "dg-crypto-adw"
  description    = "Dynamic group for ADW instance to authenticate without credentials"
  matching_rule  = "ALL {resource.type = 'autonomousdatabase', resource.compartment.id = '${var.compartment_id}'}"
}

# Policy allowing the ADW (via Dynamic Group) to read/write into the Object Storage bucket
resource "oci_identity_policy" "adw_storage_policy" {
  provider       = oci.home
  compartment_id = var.compartment_id
  name           = "policy-adw-to-storage"
  description    = "Allow ADW to manage objects in the crypto archive bucket"
  statements     = [
    "Allow dynamic-group ${oci_identity_dynamic_group.adw_dg.name} to manage objects in compartment id ${var.compartment_id} where target.bucket.name='${oci_objectstorage_bucket.crypto_archive_bucket.name}'"
  ]
}