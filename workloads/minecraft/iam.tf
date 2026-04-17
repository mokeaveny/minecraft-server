resource "azurerm_role_assignment" "minecraft_backup_role" {
    scope = azurerm_storage_account.minecraft_storage.id
    role_definition_name = "Storage Blob Data Contributor"
    principal_id = azurerm_linux_virtual_machine.minecraft_vm.identity[0].principal_id
}