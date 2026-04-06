resource "cloudflare_record" "minecraft_server_cname" {
    zone_id = "0a60ce2d42854f4c64a957f31a403506"
    name = "minecraft"
    value = azurerm_public_ip.minecraft_public_ip.fqdn
    type = "CNAME"
    proxied = false # Minecraft traffic cannot be proxied through Cloudflare
    ttl = 1
}