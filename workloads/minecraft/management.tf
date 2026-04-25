resource "azurerm_consumption_budget_resource_group" "minecraft_budget" {
  name              = "monthly-minecraft-budget"
  resource_group_id = data.terraform_remote_state.foundation.outputs.minecraft_resource_group_id
  amount            = 20
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-04-01T00:00:00Z"
    end_date   = "2027-04-01T00:00:00Z"
  }

  notification {
    enabled   = true
    threshold = 80.0
    operator  = "GreaterThan"

    contact_emails = [var.contact_email]
  }

  notification {
    enabled   = true
    threshold = 100.0
    operator  = "GreaterThan"

    contact_emails = [var.contact_email]
  }
}