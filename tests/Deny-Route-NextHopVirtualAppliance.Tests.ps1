Import-Module -Name Az.Network
Import-Module -Name Az.Resources
Import-Module "$($PSScriptRoot)/../utils/Policy.Utils.psm1" -Force
Import-Module "$($PSScriptRoot)/../utils/Rest.Utils.psm1" -Force
Import-Module "$($PSScriptRoot)/../utils/RouteTable.Utils.psm1" -Force
Import-Module "$($PSScriptRoot)/../utils/Test.Utils.psm1" -Force

Describe "Testing policy 'Deny-Route-NextHopVirtualAppliance'" -Tag "deny-route-nexthopvirtualappliance" {
    BeforeAll {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUserDeclaredVarsMoreThanAssignments', '', Scope = 'Function')]
        $TestContext = Initialize-AzPolicyTest -PolicyParameterObject @{
            "routeTableSettings" = @{
                "northeurope" = @{
                    "virtualApplianceIpAddress" = "10.0.0.23"
                }; 
                "disabled"    = @{
                    "virtualApplianceIpAddress" = ""
                }
            }
        }
    }
    
    # Create or update route is actually the same PUT request, hence testing create covers update as well.
    # PATCH requests are currently not supported in Network Resource Provider.
    # See also: https://docs.microsoft.com/en-us/rest/api/virtualnetwork/routes/createorupdate
    Context "When route is created or updated" -Tag "deny-route-nexthopvirtualappliance-route-create-update" {
        It "Should deny incompliant route 0.0.0.0/0 with next hop type 'None'" -Tag "deny-route-nexthopvirtualappliance-route-create-update-10" {
            AzPolicyTest -TestContext $TestContext {
                $routeTable = New-AzRouteTable `
                    -Name "route-table" `
                    -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                    -Location $TestContext.ResourceGroup.Location

                # Should be disallowed by policy, so exception should be thrown.
                {
                    # Directly calling REST API with PUT routes, since New-AzRouteConfig/Set-AzRouteTable will issue PUT routeTables.
                    $routeTable | Invoke-RoutePut `
                        -Name "default" `
                        -AddressPrefix "0.0.0.0/0" `
                        -NextHopType "None" # Incompliant.
                } | Should -Throw "*RequestDisallowedByPolicy*$($TestContext.PolicyDefinition.Name)*"
            }
        }

        It "Should deny incompliant route 0.0.0.0/0 with next hop IP address '10.10.10.10'" -Tag "deny-route-nexthopvirtualappliance-route-create-update-20" {
            AzPolicyTest -TestContext $TestContext {
                $routeTable = New-AzRouteTable `
                    -Name "route-table" `
                    -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                    -Location $TestContext.ResourceGroup.Location

                # Should be disallowed by policy, so exception should be thrown.
                {
                    # Directly calling REST API with PUT routes, since New-AzRouteConfig/Set-AzRouteTable will issue PUT routeTables.
                    $routeTable | Invoke-RoutePut `
                        -Name "default" `
                        -AddressPrefix "0.0.0.0/0" `
                        -NextHopType "VirtualAppliance" `
                        -NextHopIpAddress "10.10.10.10" # Incompliant.
                } | Should -Throw "*RequestDisallowedByPolicy*$($TestContext.PolicyDefinition.Name)*"
            }
        }

        It "Should allow compliant route 0.0.0.0/0" -Tag "deny-route-nexthopvirtualappliance-route-create-update-30" {
            AzPolicyTest -TestContext $TestContext {
                $routeTable = New-AzRouteTable `
                    -Name "route-table" `
                    -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                    -Location $TestContext.ResourceGroup.Location

                # Should be allowed by policy, so no exception should be thrown.
                {
                    # Directly calling REST API with PUT routes, since New-AzRouteConfig/Set-AzRouteTable will issue PUT routeTables.
                    $routeTable | Invoke-RoutePut `
                        -Name "default" `
                        -AddressPrefix "0.0.0.0/0" `
                        -NextHopType "VirtualAppliance" `
                        -NextHopIpAddress $TestContext.PolicyParameterObject.routeTableSettings.northeurope.virtualApplianceIpAddress # Compliant.
                } | Should -Not -Throw
            }
        }
    }

    # Create or update route tables is actually the same PUT request, hence testing create covers update as well.
    # PATCH requests are currently not supported in Network Resource Provider.
    # See also: https://docs.microsoft.com/en-us/rest/api/virtualnetwork/routetables/createorupdate
    Context "When route table is created or updated" -Tag "deny-route-nexthopvirtualappliance-routetable-create-update" {
        It "Should deny route table containing incompliant route 0.0.0.0/0 with next hop type 'None'" -Tag "deny-route-nexthopvirtualappliance-routetable-create-update-10" {
            AzPolicyTest -TestContext $TestContext {
                $route = New-AzRouteConfig `
                    -Name "virtual-appliance"  `
                    -AddressPrefix "0.0.0.0/0" `
                    -NextHopType "None" # Incompliant.
            
                # Should be disallowed by policy, so exception should be thrown.
                {
                    New-AzRouteTable `
                        -Name "route-table" `
                        -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                        -Location $TestContext.ResourceGroup.Location `
                        -Route $route `
                        -ErrorAction Stop # Otherwise no exception would be thrown, since $ErrorActionPreference defaults to 'Continue' in PowerShell.
                } | Should -Throw "*RequestDisallowedByPolicy*$($TestContext.PolicyDefinition.Name)*"
            }
        }

        It "Should deny route table containing incompliant route 0.0.0.0/0 with next hop IP address '10.10.10.10'" -Tag "deny-route-nexthopvirtualappliance-routetable-create-update-20" {
            AzPolicyTest -TestContext $TestContext {
                $route = New-AzRouteConfig `
                    -Name "virtual-appliance"  `
                    -AddressPrefix "0.0.0.0/0" `
                    -NextHopType "VirtualAppliance" `
                    -NextHopIpAddress "10.10.10.10" # Incompliant.
            
                # Should be disallowed by policy, so exception should be thrown.
                {
                    New-AzRouteTable `
                        -Name "route-table" `
                        -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                        -Location $TestContext.ResourceGroup.Location `
                        -Route $route `
                        -ErrorAction Stop # Otherwise no exception would be thrown, since $ErrorActionPreference defaults to 'Continue' in PowerShell.
                } | Should -Throw "*RequestDisallowedByPolicy*$($TestContext.PolicyDefinition.Name)*"
            }
        }

        It "Should allow route table containing compliant route 0.0.0.0/0" -Tag "deny-route-nexthopvirtualappliance-route-routetable-update-30" {
            AzPolicyTest -TestContext $TestContext {
                $route = New-AzRouteConfig `
                    -Name "virtual-appliance"  `
                    -AddressPrefix "0.0.0.0/0" `
                    -NextHopType "VirtualAppliance" `
                    -NextHopIpAddress $TestContext.PolicyParameterObject.routeTableSettings.northeurope.virtualApplianceIpAddress # Compliant.
            
                # Should be allowed by policy, so no exception should be thrown.
                {
                    New-AzRouteTable `
                        -Name "route-table" `
                        -ResourceGroupName $TestContext.ResourceGroup.ResourceGroupName `
                        -Location $TestContext.ResourceGroup.Location `
                        -Route $route `
                        -ErrorAction Stop # Otherwise no exception would be thrown, since $ErrorActionPreference defaults to 'Continue' in PowerShell.
                } | Should -Not -Throw
            }
        }
    }

    AfterAll {
        Clear-AzPolicyTest -TestContext $TestContext
    }
}