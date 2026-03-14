variable "home_ip_address" {
  description = "Your home IP address for NSG rule"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key for VM access"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}