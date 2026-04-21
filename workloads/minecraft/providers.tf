terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 4.66.0"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 4.38.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    container_name = "tfstate"
    key = "workload.tfstate"
    use_oidc = true
  }
}

provider "azurerm" {
  features {}
}

provider "cloudflare" {
  api_token = data.azurerm_key_vault_secret.cf_api_token.value
}

data "terraform_remote_state" "foundation" {
  backend = "azurerm"
  config = {
    resource_group_name = var.remote_state_resource_group_name
    storage_account_name = var.remote_state_storage_account_name
    container_name = "tfstate"
    key = "foundation.tfstate"
    use_oidc = true
  }
}