<#
.SYNOPSIS
Exports every Conditional Access policy to JSON and writes a one-line-per-policy summary.
.DESCRIPTION
Good for documentation, and for diffing before and after a change. Needs Policy.Read.All.
.EXAMPLE
Connect-MgGraph -Scopes Policy.Read.All
.\Export-EntraConditionalAccess.ps1 -Path .\ca-backup
#>
[CmdletBinding()]
param(
    [string]$Path = ".\ConditionalAccess-$(Get-Date -Format yyyyMMdd)"
)
#Requires -Modules Microsoft.Graph.Identity.SignIns

New-Item -ItemType Directory -Path $Path -Force | Out-Null

$policies = Get-MgIdentityConditionalAccessPolicy -All
foreach ($p in $policies) {
    $file = Join-Path $Path (($p.DisplayName -replace '[\\/:*?"<>|]', '_') + '.json')
    $p | ConvertTo-Json -Depth 10 | Set-Content -Path $file -Encoding UTF8
}

$policies | Select-Object DisplayName, State,
    @{ n = 'Users';   e = { $_.Conditions.Users.IncludeUsers + $_.Conditions.Users.IncludeGroups -join ', ' } },
    @{ n = 'Exclude'; e = { $_.Conditions.Users.ExcludeUsers + $_.Conditions.Users.ExcludeGroups -join ', ' } },
    @{ n = 'Apps';    e = { $_.Conditions.Applications.IncludeApplications -join ', ' } },
    @{ n = 'Grant';   e = { $_.GrantControls.BuiltInControls -join ', ' } },
    ModifiedDateTime |
    Tee-Object -Variable summary |
    Export-Csv (Join-Path $Path 'summary.csv') -NoTypeInformation

$summary
