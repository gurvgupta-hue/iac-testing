terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  client_secret = "SuperSecretClientKey123!"  # FLAW: hardcoded secret
}

resource "azurerm_resource_group" "test" {
  name     = "iac-test-rg"
  location = "East US"
}

# FLAW: storage account allows public blob access, uses old TLS
resource "azurerm_storage_account" "flawed" {
  name                     = "iactestflawedsa"
  resource_group_name      = azurerm_resource_group.test.name
  location                 = azurerm_resource_group.test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = true   # FLAW: should be false
  min_tls_version                 = "TLS1_0"  # FLAW: should be TLS1_2
}

# FLAW: NSG open to internet on management ports
resource "azurerm_network_security_group" "flawed" {
  name                = "iac-test-nsg"
  location            = azurerm_resource_group.test.location
  resource_group_name  = azurerm_resource_group.test.name

  security_rule {
    name                       = "AllowSSHAll"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"   # FLAW: open to any source
    destination_address_prefix = "*"
  }
}

# FLAW: unencrypted managed disk
resource "azurerm_managed_disk" "unencrypted" {
  name                 = "iac-test-disk"
  location             = azurerm_resource_group.test.location
  resource_group_name  = azurerm_resource_group.test.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
  disk_encryption_set_id = null   # FLAW: no encryption set assigned
}
