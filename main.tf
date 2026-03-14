resource "azurerm_resource_group" "minecraft_rg" {
  name     = "minecraft-resources"
  location = "UK South"
}

resource "azurerm_virtual_network" "minecraft_vnet" {
  name                = "minecraft-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.minecraft_rg.location
  resource_group_name = azurerm_resource_group.minecraft_rg.name
}

resource "azurerm_subnet" "minecraft_subnet" {
  name                 = "minecraft-subnet"
  resource_group_name  = azurerm_resource_group.minecraft_rg.name
  virtual_network_name = azurerm_virtual_network.minecraft_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Need this to have a public IP for the VM to be accessible from the internet so we can connect to the Minecraft server
resource "azurerm_public_ip" "minecraft_public_ip" {
  name                = "minecraft-ip"
  resource_group_name = azurerm_resource_group.minecraft_rg.name
  location            = azurerm_resource_group.minecraft_rg.location
  allocation_method   = "Static"
}

# This NSG allows inbound traffic on port 25565, which is the default port for Minecraft servers. It also allows all outbound traffic.
resource "azurerm_network_security_group" "minecraft_nsg" {
  name                = "minecraft-nsg"
  location            = azurerm_resource_group.minecraft_rg.location
  resource_group_name = azurerm_resource_group.minecraft_rg.name

  # Rule for Minecraft players to connect to the server
  security_rule {
    name                       = "Minecraft"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "25565"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Rule for SSH access to the VM for administration purposes
  security_rule {
    name                       = "SSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.home_ip_address # Home IP address for SSH access
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface" "minecraft_nic" {
  name                = "minecraft-nic"
  location            = azurerm_resource_group.minecraft_rg.location
  resource_group_name = azurerm_resource_group.minecraft_rg.name

  ip_configuration {
    name                          = "minecraft-ip-config"
    subnet_id                     = azurerm_subnet.minecraft_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.minecraft_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "minecraft_nic_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.minecraft_nic.id
  network_security_group_id = azurerm_network_security_group.minecraft_nsg.id
}

# Size is Standard_B2s, which is a good size for a small Minecraft server. It has 2 vCPUs and 4 GB of RAM, which should be sufficient for a small number of players.
resource "azurerm_linux_virtual_machine" "minecraft_vm" {
  name                  = "minecraft-server"
  resource_group_name   = azurerm_resource_group.minecraft_rg.name
  location              = azurerm_resource_group.minecraft_rg.location
  size                  = "Standard_B2s"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.minecraft_nic.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    # 1. Update and install Docker
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # 2. Prpare a directory for the game data (persistent storage)
    mkdir -p /home/minecraftadmin/minecraft-data
    chown -R 1000:1000 /home/minecraftadmin/minecraft-data 

    # 3. Run the Minecraft Container
    docker run -d \
      --name minecraft-server \
      -p 25565:25565 \
      -e EULA=TRUE \
      -e VERSION=LATEST \
      -e TYPE=PAPER \
      -e MEMORY=3G \
      -v /home/minecraftadmin/minecraft-data:/data \
      --restart always \
      itzg/minecraft-server
    EOF
  )

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

