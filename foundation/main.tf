data "azurerm_client_config" "current" {}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "minecraft_mgmt_rg" {
  name     = "minecraft-management-resources"
  location = "UK South"
}

resource "azurerm_key_vault" "minecraft_kv" {
  name                = "minecraft-kv-${random_id.suffix.hex}"
  location            = azurerm_resource_group.minecraft_mgmt_rg.location
  resource_group_name = azurerm_resource_group.minecraft_mgmt_rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true

  purge_protection_enabled = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_role_assignment" "minecraft_kv_admin" {
  scope                = azurerm_key_vault.minecraft_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_resource_group" "minecraft_resource_group" {
  name     = "minecraft-resources"
  location = "UK South"
}

# Grant GitHub Actions Contributor access to the Minecraft resource group so that it can create and manage resources within it.
resource "azurerm_role_assignment" "github_actions_contributor" {
  scope                = azurerm_resource_group.minecraft_resource_group.id
  role_definition_name = "Contributor"
  principal_id         = var.github_actions_service_principal_object_id
}

# Grant GitHub Actions User Access Administrator access to the Minecraft resource group so that it can create or delete role assigmments within it.
resource "azurerm_role_assignment" "github_actions_user_access_administrator" {
  scope                = azurerm_resource_group.minecraft_resource_group.id
  role_definition_name = "User Access Administrator"
  principal_id         = var.github_actions_service_principal_object_id
}

output "resource_group_name" {
  value = azurerm_resource_group.minecraft_mgmt_rg.name
}

output "minecraft_resource_group_name" {
  value = azurerm_resource_group.minecraft_resource_group.name
}

output "minecraft_resource_group_location" {
  value = azurerm_resource_group.minecraft_resource_group.location
}

output "minecraft_resource_group_id" {
  value = azurerm_resource_group.minecraft_resource_group.id
}

output "key_vault_name" {
  value = azurerm_key_vault.minecraft_kv.name
}

output "key_vault_id" {
  value = azurerm_key_vault.minecraft_kv.id
}