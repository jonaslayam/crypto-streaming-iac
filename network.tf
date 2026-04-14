
# 1. Virtual Cloud Network (VCN)

resource "oci_core_vcn" "streaming_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = "10.0.0.0/16"
  display_name   = "vcn-crypto-streaming"
  dns_label      = "cryptovcn"
}

# 2. Gateways (Internet & Service)

# IGW for public inbound (SSH) and outbound API calls (Binance)
resource "oci_core_internet_gateway" "streaming_ig" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.streaming_vcn.id
  display_name   = "ig-crypto-streaming"
}

# 3. Route Table

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

# 4. Security List (Firewall Rules)

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

  # Allow SQL*Net (port 1522) from your public IP for local Producer connection
  ingress_security_rules {
    protocol    = "6"
    source      = local.current_ip
    description = "Allow external SQL*Net access from developer machine"
    tcp_options {
      min = 1522
      max = 1522
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

# 5. Public Subnet

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
