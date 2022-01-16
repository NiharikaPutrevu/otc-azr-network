#Azure Generic vNet Module
data "azurerm_resource_group" "vnet" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = data.azurerm_resource_group.vnet.name
  location            = coalesce(var.vnet_location, data.azurerm_resource_group.vnet.location)
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "subnet" {
  count = length(var.subnet_names)

  name                                           = var.subnet_names[count.index]
  resource_group_name                            = data.azurerm_resource_group.vnet.name
  virtual_network_name                           = azurerm_virtual_network.vnet.name
  address_prefixes                               = [var.subnet_prefixes[count.index]]
  service_endpoints                              = lookup(var.subnet_service_endpoints, var.subnet_prefixes[count.index], null)
  enforce_private_link_endpoint_network_policies = lookup(var.subnet_enforce_private_link_endpoint_network_policies, var.subnet_prefixes[count.index], false)
  enforce_private_link_service_network_policies  = lookup(var.subnet_enforce_private_link_service_network_policies, var.subnet_prefixes[count.index], false)

  dynamic "delegation" {
    for_each = lookup(var.subnet_delegations, var.subnet_prefixes[count.index], null) != null ? [1] : []

    content {
      name = var.subnet_delegations[var.subnet_prefixes[count.index]]["name"]
      service_delegation {
        name    = var.subnet_delegations[var.subnet_prefixes[count.index]]["name"]
        actions = var.subnet_delegations[var.subnet_prefixes[count.index]]["actions"]
      }
    }
  }
}

resource "azurerm_private_dns_zone" "private_dns" {
  for_each = var.private_dns_zones

  name                = each.value
  resource_group_name = data.azurerm_resource_group.vnet.name

  tags = var.tags
}


resource "azurerm_private_dns_zone_virtual_network_link" "dns" {
  for_each = azurerm_private_dns_zone.private_dns

  name                  = "${azurerm_virtual_network.vnet.name}-${each.key}"
  resource_group_name   = data.azurerm_resource_group.vnet.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.vnet.id

  tags = var.tags
}
