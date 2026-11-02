<#
.SYNOPSIS
Recent account lockouts and the computer each one came from.
.DESCRIPTION
Reads event 4740 from the PDC emulator, where every lockout is recorded.
Caller computer is where the bad passwords came from (phone, old mapped drive, service, etc.).
.EXAMPLE
.\Get-ADLockoutSource.ps1 -Hours 4
.EXAMPLE
.\Get-ADLockoutSource.ps1 -User jdoe -Hours 48
#>
[CmdletBinding()]
param(
    [int]$Hours = 24,
    [string]$User
)
#Requires -Modules ActiveDirectory

$pdc = (Get-ADDomain).PDCEmulator
# No lockouts in the window is normal; anything else (access denied, PDC down) is a real error
try {
    $events = Get-WinEvent -ComputerName $pdc -ErrorAction Stop -FilterHashtable @{
        LogName   = 'Security'
        Id        = 4740
        StartTime = (Get-Date).AddHours(-$Hours)
    }
}
catch {
    if ($_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*') { throw }
    $events = @()
}

$events | ForEach-Object {
    [pscustomobject]@{
        Time           = $_.TimeCreated
        User           = $_.Properties[0].Value
        CallerComputer = $_.Properties[1].Value
        DC             = $pdc
    }
} | Where-Object { -not $User -or $_.User -eq $User }
