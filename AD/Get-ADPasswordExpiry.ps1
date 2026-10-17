<#
.SYNOPSIS
Users whose passwords expire in the next X days. Honors fine-grained password policies.
.EXAMPLE
.\Get-ADPasswordExpiry.ps1 -Days 14 | Sort-Object Expires | Format-Table
#>
[CmdletBinding()]
param(
    [int]$Days = 14
)
#Requires -Modules ActiveDirectory

$until = (Get-Date).AddDays($Days)

Get-ADUser -Filter { Enabled -eq $true -and PasswordNeverExpires -eq $false } `
    -Properties 'msDS-UserPasswordExpiryTimeComputed', mail |
    ForEach-Object {
        $raw = $_.'msDS-UserPasswordExpiryTimeComputed'
        # 0 = must change at next logon; max value = never expires
        if ($raw -and $raw -ne 9223372036854775807) {
            $expires = [datetime]::FromFileTime($raw)
            if ($expires -le $until) {
                [pscustomobject]@{
                    SamAccountName = $_.SamAccountName
                    Name           = $_.Name
                    Mail           = $_.mail
                    Expires        = $expires
                    DaysLeft       = [int]($expires - (Get-Date)).TotalDays
                }
            }
        }
    }
