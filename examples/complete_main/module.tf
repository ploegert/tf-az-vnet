
locals {

  naming_product = "app"
  naming_component = "core"
  naming_env = "z"
  naming_project = ""
  naming_zone = "z1"
 
  prefix = ["${local.naming_product}${local.naming_env}${local.naming_zone}", local.naming_component ]

  global_settings = {
    region_primary      = "eastus2"
    region_secondary    = "eastus"
    prefix              = local.prefix
    suffix              = [ ]

    core_rg             = module.naming.resource_group.name
    core_vnet_name      = module.naming.virtual_network.name
  }
}

module "naming" {
  # source  = "github.com/Azure/terraform-azurerm-naming"
  source  = "github.com/ploegert/terraform-azurerm-naming"

  prefix = local.prefix
  suffix = [ ]
}




module "vnet" {
  source  = "../../"
  # version = "2.0.0"

  # By default, this module will not create a resource group, proivde the name here
  # to use an existing resource group, specify the existing resource group name,
  # and set the argument to `create_resource_group = true`. Location will be same as existing RG.
  create_resource_group          = true
  resource_group_name            = local.global_settings.core_rg
  vnetwork_name                  = local.global_settings.core_vnet_name
  location                       = local.global_settings.region_primary

  vnet_address_space             = ["172.17.0.0/16","192.168.196.192/28"] # 172.17.0.1 - 172.17.255.254
  #firewall_subnet_address_prefix = []
  gateway_subnet_address_prefix  = ["192.168.196.192/28"]

  # Adding Standard DDoS Plan, and custom DNS servers (Optional)
  create_ddos_plan               = false
  ddos_plan_name                 = module.naming.network_ddos_protection_plan.name

  create_network_watcher         = false
  network_watcher_name           = module.naming.network_watcher.name

  nsg_name                       = module.naming.network_security_group.name

  #create_private_dns             = true
  dns = {
    private_dns_zone_name       = "privatelink.${local.global_settings.region_primary}.azmk8s.io"
    link_name                   = module.naming.private_link_service.name
    vnet_auto_registration      = true
  }

  subnets = {
    aks_subnet = {
      subnet_name           = "${module.naming.subnet.name}-aks"
      subnet_address_prefix = ["172.17.0.0/22"]   # 172.17.0.1 - 172.17.3.254
      nsg_inbound_rules = []
      nsg_outbound_rules = []
      service_endpoints = ["Microsoft.Sql","Microsoft.EventHub","Microsoft.KeyVault","Microsoft.Storage","Microsoft.AzureCosmosDB"]
    }
    common_subnet = {
      subnet_name           = "${module.naming.subnet.name}-common"
      subnet_address_prefix = [ "172.17.8.0/24"] # 172.17.8.1 - 172.17.8.254
      nsg_inbound_rules = []
      nsg_outbound_rules = []
      service_endpoints = ["Microsoft.Sql","Microsoft.EventHub","Microsoft.KeyVault","Microsoft.Storage","Microsoft.AzureCosmosDB"]
    }
    function_subnet = {
      subnet_name           = "${module.naming.subnet.name}-function"
      subnet_address_prefix = ["172.17.9.0/24"] # 172.17.9.1 - 172.17.9.254
      nsg_inbound_rules = []
      nsg_outbound_rules = []
      service_endpoints = ["Microsoft.Sql","Microsoft.EventHub","Microsoft.KeyVault","Microsoft.Storage","Microsoft.AzureCosmosDB"]
      delegation = {
        name = "functionapp-delegation"
        service_delegation = {
          name    = "Microsoft.Web/serverFarms"
          actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
        }
      }
    }
    
    endpoints_subnet = {
      subnet_name           = "${module.naming.subnet.name}-endpoints"
      subnet_address_prefix = ["172.17.4.0/22"]   # 172.17.4.1 - 172.17.7.254
      enforce_private_link_service_network_policies = false
      enforce_private_link_endpoint_network_policies = true
      # delegation = {
      #   name = "testdelegation"
      #   service_delegation = {
      #     name    = "Microsoft.ContainerInstance/containerGroups"
      #     actions = ["Microsoft.Network/virtualNetworks/subnets/join/action", "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action"]
      #   }
      # }
      nsg_inbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        # ["weballow", "100", "Inbound", "Allow", "Tcp", "80", "*", "0.0.0.0/0"],
        # ["weballow1", "101", "Inbound", "Allow", "", "443", "*", ""],
        # ["weballow2", "102", "Inbound", "Allow", "Tcp", "8080-8090", "*", ""],
      ]

      nsg_outbound_rules = [
        # [name, priority, direction, access, protocol, destination_port_range, source_address_prefix, destination_address_prefix]
        # To use defaults, use "" without adding any values.
        # ["ntp_out", "103", "Outbound", "Allow", "Udp", "123", "", "0.0.0.0/0"],
      ]
    }

  }

  # Adding TAG's to your Azure resources (Required)
  tags = {
    ProjectName  = "demo-internal"
    Env          = "dev"
    Owner        = "user@example.com"
    BusinessUnit = "CORP"
    ServiceClass = "Gold"
  }
}
