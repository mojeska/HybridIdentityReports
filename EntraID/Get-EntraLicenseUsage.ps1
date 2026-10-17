<#
.SYNOPSIS
Licenses bought vs assigned, per SKU.
.DESCRIPTION
Needs Organization.Read.All.
.EXAMPLE
Connect-MgGraph -Scopes Organization.Read.All
.\Get-EntraLicenseUsage.ps1 | Format-Table
#>
[CmdletBinding()]
param()
#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement

Get-MgSubscribedSku -All | ForEach-Object {
    [pscustomobject]@{
        Sku       = $_.SkuPartNumber
        Purchased = $_.PrepaidUnits.Enabled
        Assigned  = $_.ConsumedUnits
        Available = $_.PrepaidUnits.Enabled - $_.ConsumedUnits
        Suspended = $_.PrepaidUnits.Suspended
        Warning   = $_.PrepaidUnits.Warning
    }
} | Sort-Object Sku
