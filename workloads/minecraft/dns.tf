resource "cloudflare_record" "minecraft_server_cname" {
    zone_id = data.azurerm_key_vault_secret.cf_zone_id.value
    name = "minecraft"
    value = azurerm_public_ip.minecraft_public_ip.fqdn
    type = "CNAME"
    proxied = false # Minecraft traffic cannot be proxied through Cloudflare
    ttl = 1
}