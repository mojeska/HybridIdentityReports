<#
.SYNOPSIS
Enabled computer accounts that haven't logged on in X days.
.DESCRIPTION
Uses lastLogonTimestamp (replicated, accurate to about 14 days).
.EXAMPLE
.\Get-StaleADComputers.ps1 -Days 90 | Export-Csv stale-computers.csv -NoTypeInformation
#>
[CmdletBinding()]
param(
    [int]$Days = 90,
    [string]$SearchBase
)
#Requires -Modules ActiveDirectory

$cutoff = (Get-Date).AddDays(-$Days)
$params = @{
    Filter     = { Enabled -eq $true }
    Properties = 'lastLogonTimestamp', 'OperatingSystem', 'whenCreated', 'Description'
}
if ($SearchBase) { $params.SearchBase = $SearchBase }

Get-ADComputer @params |
    Where-Object { -not $_.lastLogonTimestamp -or [datetime]::FromFileTime($_.lastLogonTimestamp) -lt $cutoff } |
    Select-Object Name, OperatingSystem,
        @{ n = 'LastLogon'; e = { if ($_.lastLogonTimestamp) { [datetime]::FromFileTime($_.lastLogonTimestamp) } } },
        whenCreated, Description, DistinguishedName |
    Sort-Object LastLogon
