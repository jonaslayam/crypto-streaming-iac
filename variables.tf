variable "tenancy_ocid" {
  type        = string
  description = "The OCID of the OCI tenancy"
}

variable "user_ocid" {
  type        = string
  description = "The OCID of the OCI user"
}

variable "fingerprint" {
  type        = string
  description = "The fingerprint of the OCI API key"
}

variable "private_key_path" {
  type        = string
  description = "The local path to the OCI private key .pem file"
}

variable "region" {
  type        = string
  description = "The OCI region (e.g., us-ashburn-1)"
}

variable "compartment_id" {
  type        = string
  description = "The OCID of the compartment where infrastructure will be created"
}

variable "ssh_public_key_path" {
  type        = string
  description = "The local path to your public SSH key (id_rsa.pub)"
}

variable "adw_admin_password" {
  description = "Password for the ADW admin user"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email address to receive FinOps budget alerts"
  type        = string
}

variable "oci_username" {
  description = "Your OCI username (usually your email) for Docker login to OCIR"
  type        = string
}

variable "ocir_auth_token" {
  description = "The Auth Token generated in the OCI IAM console for 'docker login'"
  type        = string
  sensitive   = true # Keeps the token hidden in logs
}