output "public_ip_address" {
  description = "The public IP address of the Minecraft server"
  value       = azurerm_public_ip.minecraft_public_ip.ip_address
}

output "ssh_connection_string" {
  description = "Copy and paste this command to log into your server"
  value       = "ssh minecraftadmin@${azurerm_public_ip.minecraft_public_ip.ip_address}"
}