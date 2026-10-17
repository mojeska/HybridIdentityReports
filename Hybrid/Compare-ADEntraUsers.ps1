<#
.SYNOPSIS
Enabled AD users that aren't in Entra ID, and synced Entra users whose AD account is disabled.
.DESCRIPTION
Matches on UPN. Catches users outside the sync scope (wrong OU) and leavers still enabled in the cloud.
Needs the ActiveDirectory module and User.Read.All.
.EXAMPLE
Connect-MgGraph -Scopes User.Read.All
.\Compare-ADEntraUsers.ps1 -SearchBase 'OU=Staff,DC=contoso,DC=com' | Format-Table
#>
[CmdletBinding()]
param(
    [string]$SearchBase
)
#Requires -Modules ActiveDirectory, Microsoft.Graph.Users

$adParams = @{ Filter = '*'; Properties = 'UserPrincipalName', 'Enabled' }
if ($SearchBase) { $adParams.SearchBase = $SearchBase }
$ad = Get-ADUser @adParams | Where-Object UserPrincipalName

$entra = Get-MgUser -All -Property UserPrincipalName, AccountEnabled, OnPremisesSyncEnabled
$entraByUpn = @{}
foreach ($u in $entra) { $entraByUpn[$u.UserPrincipalName.ToLower()] = $u }

foreach ($a in $ad) {
    $match = $entraByUpn[$a.UserPrincipalName.ToLower()]
    if ($a.Enabled -and -not $match) {
        [pscustomobject]@{ UPN = $a.UserPrincipalName; Issue = 'Enabled in AD, not in Entra ID (outside sync scope?)' }
    }
    elseif (-not $a.Enabled -and $match.AccountEnabled -and $match.OnPremisesSyncEnabled) {
        [pscustomobject]@{ UPN = $a.UserPrincipalName; Issue = 'Disabled in AD, still enabled in Entra ID (sync lag or error?)' }
    }
}
