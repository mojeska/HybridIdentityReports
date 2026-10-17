<#
.SYNOPSIS
Who is and isn't registered for MFA, and with which methods.
.DESCRIPTION
Uses the authentication methods registration report. Needs AuditLog.Read.All and Entra ID P1 or P2.
.EXAMPLE
Connect-MgGraph -Scopes AuditLog.Read.All
.\Get-EntraMfaRegistration.ps1 -NotRegisteredOnly | Format-Table
#>
[CmdletBinding()]
param(
    [switch]$NotRegisteredOnly
)
#Requires -Modules Microsoft.Graph.Reports

Get-MgReportAuthenticationMethodUserRegistrationDetail -All |
    Where-Object { -not $NotRegisteredOnly -or -not $_.IsMfaRegistered } |
    Select-Object UserPrincipalName, UserDisplayName, IsAdmin, IsMfaRegistered, IsMfaCapable,
        IsPasswordlessCapable,
        @{ n = 'Methods'; e = { $_.MethodsRegistered -join ', ' } },
        @{ n = 'DefaultMethod'; e = { $_.UserPreferredMethodForSecondaryAuthentication } } |
    Sort-Object IsMfaRegistered, UserPrincipalName
