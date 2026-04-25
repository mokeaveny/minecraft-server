resource "azurerm_storage_account" "minecraft_storage" {
  name                     = "minecraftbackups${random_id.suffix.hex}"
  resource_group_name      = data.terraform_remote_state.foundation.outputs.minecraft_resource_group_name
  location                 = data.terraform_remote_state.foundation.outputs.minecraft_resource_group_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "minecraft_backups" {
  name                  = "minecraft-world-backups"
  storage_account_name  = azurerm_storage_account.minecraft_storage.name
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "cleanup" {
  storage_account_id = azurerm_storage_account.minecraft_storage.id

  rule {
    name    = "delete-old-backups"
    enabled = true

    filters {
      prefix_match = ["minecraft-world-backups/backups/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 7
      }
    }
  }
}