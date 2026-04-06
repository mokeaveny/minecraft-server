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

variable "minecraft_memory" {
  description = "Amount of memory (in GB) to allocate to the Minecraft server"
  type        = string
  default     = "3G" # Default to 3 GB of RAM, which is a good starting point for a small server
}

variable "contact_email" {
  description = "Email address to receive budget notifications"
  type        = string
}

variable "cloudflare_api_token" {
  description = "API token for Cloudflare with permissions to manage DNS records"
  type        = string
}