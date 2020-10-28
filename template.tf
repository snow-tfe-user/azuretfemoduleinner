resource "azurerm_resource_group" "resource_group" {
  name     = var.azure_rgname
  location = var.azure_location
}

#db servers...
resource "azurerm_managed_disk" "db_datadisk0" {
  count                = var.azure_resource_count
  name                 = "db_datadisk0-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  location             = azurerm_resource_group.resource_group.location
  resource_group_name  = azurerm_resource_group.resource_group.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"
}

resource "azurerm_managed_disk" "db_datadisk1" {
  count                = var.azure_resource_count
  name                 = "db_datadisk1-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  location             = azurerm_resource_group.resource_group.location
  resource_group_name  = azurerm_resource_group.resource_group.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  depends_on           = [ azurerm_managed_disk.db_datadisk0 ]
}

resource "azurerm_network_interface" "db-nic" {
  count               = var.azure_resource_count
  name                = "db-nic-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "db-nic-ip-config-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
    subnet_id                     = var.azure_db_subnet_id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }

  depends_on          = [ azurerm_managed_disk.db_datadisk0 ]
}

resource "azurerm_linux_virtual_machine" "db" {
  count                           = var.azure_resource_count
  name                            = "db-vm-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  resource_group_name             = azurerm_resource_group.resource_group.name
  location                        = azurerm_resource_group.resource_group.location
  size                            = var.azure_db_vm_size

  depends_on                      = [ azurerm_managed_disk.db_datadisk1 ]

  admin_username                  = "sncuser"
  admin_password                  = "Snow@2020"
  disable_password_authentication = false

  network_interface_ids = [ azurerm_network_interface.db-nic[count.index].id ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.azure_db_vm_sku
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "db_datadisk0attachment" {
  count              = var.azure_resource_count
  managed_disk_id    = azurerm_managed_disk.db_datadisk0[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.db[count.index].id
  lun                = "11"
  caching            = "ReadOnly"
}

resource "azurerm_virtual_machine_data_disk_attachment" "db_datadisk1attachment" {
  count              = var.azure_resource_count
  managed_disk_id    = azurerm_managed_disk.db_datadisk1[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.db[count.index].id
  lun                = "12"
  caching            = "ReadOnly"
  depends_on         = [ azurerm_virtual_machine_data_disk_attachment.db_datadisk0attachment ]
}

#app servers...
resource "azurerm_managed_disk" "app_datadisk0" {
  count                = var.azure_resource_count
  name                 = "app_datadisk0-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  location             = azurerm_resource_group.resource_group.location
  resource_group_name  = azurerm_resource_group.resource_group.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1"

  depends_on = [ azurerm_virtual_machine_data_disk_attachment.db_datadisk1attachment ]
}

resource "azurerm_network_interface" "app-nic" {
  count               = var.azure_resource_count
  name                = "app-nic-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "app-nic-ip-config-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
    subnet_id                     = var.azure_app_subnet_id
    private_ip_address_allocation = "Dynamic"
    private_ip_address_version    = "IPv4"
  }

  depends_on = [ azurerm_managed_disk.app_datadisk0 ]
}

resource "azurerm_linux_virtual_machine" "app" {
  count                           = var.azure_resource_count
  name                            = "app-vm-${format("%00.0f", count.index)}-${substr(azurerm_resource_group.resource_group.name,13,16)}"
  resource_group_name             = azurerm_resource_group.resource_group.name
  location                        = azurerm_resource_group.resource_group.location
  size                            = var.azure_app_vm_size
  
  depends_on                      = [ azurerm_managed_disk.app_datadisk0 ]

  admin_username                  = "sncuser"
  admin_password                  = "Snow@2020"
  disable_password_authentication = false

  network_interface_ids = [ azurerm_network_interface.app-nic[count.index].id ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = var.azure_app_vm_sku
    version   = "latest"
  }
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_datadisk0attachment" {
  count              = var.azure_resource_count
  managed_disk_id    = azurerm_managed_disk.app_datadisk0[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.app[count.index].id
  lun                = "11"
  caching            = "ReadOnly"
}
