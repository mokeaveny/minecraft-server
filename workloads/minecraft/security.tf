# 1. Fetch the Key Vault details from the Foundation state
data "azurerm_key_vault" "minecraft_mgmt_vault" {
  name                = data.terraform_remote_state.foundation.outputs.key_vault_name
  resource_group_name = data.terraform_remote_state.foundation.outputs.resource_group_name
}

# 2. Fetch the Secrets from that Vault
data "azurerm_key_vault_secret" "cf_api_token" {
  name         = "cloudflare-api-token"
  key_vault_id = data.azurerm_key_vault.minecraft_mgmt_vault.id
}

data "azurerm_key_vault_secret" "cf_zone_id" {
  name         = "cloudflare-zone-id"
  key_vault_id = data.azurerm_key_vault.minecraft_mgmt_vault.id
}