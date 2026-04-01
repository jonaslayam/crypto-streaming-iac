# OCI Object Storage (Cold Data)

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