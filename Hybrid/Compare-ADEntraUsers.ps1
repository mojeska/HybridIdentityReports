<#
.SYNOPSIS
Enabled AD users that aren't in Entra ID, and synced Entra users whose AD account is disabled.
.DESCRIPTION
Matches on the AD SID (onPremisesSecurityIdentifier in Entra), so it works when the AD UPN suffix
isn't routable (e.g. .local) and Entra Connect gave the user an onmicrosoft.com UPN.
Catches users outside the sync scope (wrong OU) and leavers still enabled in the cloud.
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

$adParams = @{ Filter = '*'; Properties = 'UserPrincipalName', 'Enabled', 'objectSid' }
if ($SearchBase) { $adParams.SearchBase = $SearchBase }
$ad = Get-ADUser @adParams

$entra = Get-MgUser -All -Property UserPrincipalName, AccountEnabled, OnPremisesSyncEnabled, OnPremisesSecurityIdentifier
$entraBySid = @{}
foreach ($u in $entra | Where-Object OnPremisesSecurityIdentifier) { $entraBySid[$u.OnPremisesSecurityIdentifier] = $u }

foreach ($a in $ad) {
    $match = $entraBySid[$a.SID.Value]
    if ($a.Enabled -and -not $match) {
        [pscustomobject]@{ SamAccountName = $a.SamAccountName; ADUpn = $a.UserPrincipalName; EntraUpn = $null
            Issue = 'Enabled in AD, not in Entra ID (outside sync scope?)' }
    }
    elseif (-not $a.Enabled -and $match.AccountEnabled -and $match.OnPremisesSyncEnabled) {
        [pscustomobject]@{ SamAccountName = $a.SamAccountName; ADUpn = $a.UserPrincipalName; EntraUpn = $match.UserPrincipalName
            Issue = 'Disabled in AD, still enabled in Entra ID (sync lag or error?)' }
    }
}
