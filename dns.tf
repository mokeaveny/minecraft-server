resource "cloudflare_record" "minecraft_server_cname" {
    zone_id = var.cloudflare_zone_id
    name = "minecraft"
    value = azurerm_public_ip.minecraft_public_ip.fqdn
    type = "CNAME"
    proxied = false # Minecraft traffic cannot be proxied through Cloudflare
    ttl = 1
}