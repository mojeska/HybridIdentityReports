<#
.SYNOPSIS
Enabled users inactive for X days, never logged on, or set to password never expires.
.EXAMPLE
.\Get-StaleADUsers.ps1 -Days 90 | Where-Object Reason -match 'Inactive' | Format-Table
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
    Properties = 'lastLogonTimestamp', 'PasswordLastSet', 'PasswordNeverExpires', 'whenCreated', 'Title', 'Department'
}
if ($SearchBase) { $params.SearchBase = $SearchBase }

foreach ($u in Get-ADUser @params) {
    $last = if ($u.lastLogonTimestamp) { [datetime]::FromFileTime($u.lastLogonTimestamp) }
    $reasons = @()
    if (-not $last -and $u.whenCreated -lt $cutoff) { $reasons += 'NeverLoggedOn' }
    elseif ($last -and $last -lt $cutoff) { $reasons += "Inactive${Days}d" }
    if ($u.PasswordNeverExpires) { $reasons += 'PasswordNeverExpires' }
    if (-not $reasons) { continue }

    [pscustomobject]@{
        SamAccountName  = $u.SamAccountName
        Name            = $u.Name
        Reason          = $reasons -join ', '
        LastLogon       = $last
        PasswordLastSet = $u.PasswordLastSet
        Created         = $u.whenCreated
        Title           = $u.Title
        Department      = $u.Department
        OU              = ($u.DistinguishedName -replace '^CN=[^,]+,')
    }
}
