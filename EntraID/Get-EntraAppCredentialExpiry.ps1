<#
.SYNOPSIS
App registration secrets and certificates that expire in the next X days (or already have).
.DESCRIPTION
Needs Application.Read.All.
.EXAMPLE
Connect-MgGraph -Scopes Application.Read.All
.\Get-EntraAppCredentialExpiry.ps1 -Days 60 | Format-Table
#>
[CmdletBinding()]
param(
    [int]$Days = 30
)
#Requires -Modules Microsoft.Graph.Applications

$until = (Get-Date).AddDays($Days)

foreach ($app in Get-MgApplication -All -Property DisplayName, AppId, PasswordCredentials, KeyCredentials) {
    $creds = @(
        $app.PasswordCredentials | ForEach-Object { [pscustomobject]@{ Type = 'Secret'; Name = $_.DisplayName; End = $_.EndDateTime } }
        $app.KeyCredentials      | ForEach-Object { [pscustomobject]@{ Type = 'Certificate'; Name = $_.DisplayName; End = $_.EndDateTime } }
    )
    foreach ($c in $creds | Where-Object { $_.End -and $_.End -le $until }) {
        [pscustomobject]@{
            App      = $app.DisplayName
            AppId    = $app.AppId
            Type     = $c.Type
            Name     = $c.Name
            Expires  = $c.End
            DaysLeft = [int]($c.End - (Get-Date)).TotalDays
        }
    }
}
