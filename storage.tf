resource "azurerm_storage_account" "minecraft_storage" {
  name = "minecraftbackups${random_id.suffix.hex}"
  resource_group_name = azurerm_resource_group.minecraft_rg.name
  location = azurerm_resource_group.minecraft_rg.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "minecraft_backups" {
    name = "minecraft-world-backups"
    storage_account_name = azurerm_storage_account.minecraft_storage.name
    container_access_type = "private"
}