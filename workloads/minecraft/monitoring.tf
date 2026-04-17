resource "azurerm_log_analytics_workspace" "minecraft_logs" {
  name                = "law-minecraft-${random_id.suffix.hex}"
  location            = azurerm_resource_group.minecraft_rg.location
  resource_group_name = azurerm_resource_group.minecraft_rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_data_collection_rule" "minecraft_dcr" {
  name                = "dcr-minecraft-metrics"
  resource_group_name = azurerm_resource_group.minecraft_rg.name
  location            = azurerm_resource_group.minecraft_rg.location

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.minecraft_logs.id
      name                  = "destination-log-analytics"
    }
  }

  data_flow {
    streams      = ["Microsoft-Perf"]
    destinations = ["destination-log-analytics"]
  }

  data_sources {
    performance_counter {
      streams                       = ["Microsoft-Perf"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "Processor(*)\\% Processor Time",
        "Memory(*)\\Available MBytes",
        "LogicalDisk(*)\\% Free Space"
      ]
      name = "minecraft-perf-counters"
    }
    syslog {
      streams        = ["Microsoft-Syslog"]
      facility_names = ["*"]
      log_levels     = ["Warning", "Error", "Critical", "Alert", "Emergency"]
      name           = "minecraft-syslog"
    }
  }
}

resource "azurerm_virtual_machine_extension" "ama" {
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.minecraft_vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}

resource "azurerm_monitor_data_collection_rule_association" "minecraft_dcr_association" {
  name                    = "dcra-minecraft-metrics"
  target_resource_id      = azurerm_linux_virtual_machine.minecraft_vm.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.minecraft_dcr.id
}