<#
.SYNOPSIS
Everyone in the built-in admin groups, nested members included.
.DESCRIPTION
Domain Admins, Enterprise Admins, Schema Admins, Administrators, Account/Server/Backup/Print Operators.
Flags disabled accounts, old passwords and accounts that haven't logged on recently.
.EXAMPLE
.\Get-ADPrivilegedMembers.ps1 | Format-Table Group, SamAccountName, Enabled, PasswordAgeDays, LastLogon
#>
[CmdletBinding()]
param(
    [string[]]$Group = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators',
                         'Account Operators', 'Server Operators', 'Backup Operators', 'Print Operators')
)
#Requires -Modules ActiveDirectory

foreach ($g in $Group) {
    try { $members = Get-ADGroupMember -Identity $g -Recursive -ErrorAction Stop }
    catch { Write-Warning "$g - $($_.Exception.Message)"; continue }

    foreach ($m in $members | Where-Object objectClass -eq 'user') {
        $u = Get-ADUser $m -Properties Enabled, PasswordLastSet, lastLogonTimestamp, PasswordNeverExpires
        [pscustomobject]@{
            Group                = $g
            SamAccountName       = $u.SamAccountName
            Name                 = $u.Name
            Enabled              = $u.Enabled
            PasswordAgeDays      = if ($u.PasswordLastSet) { [int]((Get-Date) - $u.PasswordLastSet).TotalDays }
            PasswordNeverExpires = $u.PasswordNeverExpires
            LastLogon            = if ($u.lastLogonTimestamp) { [datetime]::FromFileTime($u.lastLogonTimestamp) }
        }
    }
}
