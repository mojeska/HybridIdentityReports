<#
.SYNOPSIS
Is directory sync running, when did it last run, and which synced objects have errors.
.DESCRIPTION
Run from anywhere with Graph access. Needs Organization.Read.All and User.Read.All.
On the Entra Connect server itself, Get-ADSyncScheduler and Get-ADSyncConnectorRunStatus
give more detail.
.EXAMPLE
Connect-MgGraph -Scopes Organization.Read.All, User.Read.All
.\Get-HybridSyncStatus.ps1
#>
[CmdletBinding()]
param(
    [int]$WarnMinutes = 90
)
#Requires -Modules Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Users

$org = Get-MgOrganization
$last = $org.OnPremisesLastSyncDateTime
$minutes = if ($last) { [int]((Get-Date).ToUniversalTime() - $last.ToUniversalTime()).TotalMinutes }

[pscustomobject]@{
    Tenant          = $org.DisplayName
    SyncEnabled     = $org.OnPremisesSyncEnabled
    LastSync        = $last
    MinutesAgo      = $minutes
    Healthy         = [bool]($org.OnPremisesSyncEnabled -and $null -ne $minutes -and $minutes -le $WarnMinutes)
} | Format-List

# Users with sync (provisioning) errors, e.g. duplicate UPN or proxyAddress
$errors = Get-MgUser -All -Property DisplayName, UserPrincipalName, OnPremisesSyncEnabled, OnPremisesProvisioningErrors |
    Where-Object { $_.OnPremisesProvisioningErrors }

if ($errors) {
    $errors | ForEach-Object {
        foreach ($e in $_.OnPremisesProvisioningErrors) {
            [pscustomobject]@{
                User     = $_.UserPrincipalName
                Category = $e.Category
                Property = $e.PropertyCausingError
                Value    = $e.Value
                Occurred = $e.OccurredDateTime
            }
        }
    }
} else {
    Write-Output 'No user provisioning errors.'
}
