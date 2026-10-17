<#
.SYNOPSIS
Guest accounts that haven't signed in for X days, or never accepted the invite.
.DESCRIPTION
Sign-in data needs AuditLog.Read.All and Entra ID P1 or P2.
.EXAMPLE
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All
.\Get-EntraStaleGuests.ps1 -Days 90 | Export-Csv stale-guests.csv -NoTypeInformation
#>
[CmdletBinding()]
param(
    [int]$Days = 90
)
#Requires -Modules Microsoft.Graph.Users

$cutoff = (Get-Date).AddDays(-$Days)

Get-MgUser -All -Filter "userType eq 'Guest'" `
    -Property DisplayName, Mail, UserPrincipalName, CreatedDateTime, ExternalUserState, SignInActivity |
    ForEach-Object {
        $last = $_.SignInActivity.LastSignInDateTime
        if ($_.ExternalUserState -eq 'PendingAcceptance' -or -not $last -or $last -lt $cutoff) {
            [pscustomobject]@{
                DisplayName = $_.DisplayName
                Mail        = $_.Mail
                Invite      = $_.ExternalUserState
                Created     = $_.CreatedDateTime
                LastSignIn  = $last
            }
        }
    } | Sort-Object LastSignIn
