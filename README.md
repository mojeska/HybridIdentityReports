# HybridIdentityReports

[![CI](https://github.com/mojeska/HybridIdentityReports/actions/workflows/ci.yml/badge.svg)](https://github.com/mojeska/HybridIdentityReports/actions/workflows/ci.yml)

Report scripts for hybrid AD + Entra ID environments. All read-only. Pipe to
`Export-Csv` or `Format-Table` as needed.

## Disclaimer

> [!WARNING]
> **Use at your own risk.** These scripts are provided as-is, with no warranty or guarantee of any kind. The author accepts no liability for any damage, data loss, downtime or other problems that result from using them.
>
> Read and understand anything before you run it, do your own research, and test in a lab before using it in production. See the [MIT License](LICENSE) for the full terms.

## Setup

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser       # scripts aren't signed
Unblock-File .\*\*.ps1                                    # if you downloaded a ZIP

Install-WindowsFeature RSAT-AD-PowerShell                 # AD scripts, on a server
Install-Module Microsoft.Graph -Scope CurrentUser         # Entra ID scripts
```

Connect to Graph with the scopes the script lists, e.g.:

```powershell
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Application.Read.All, Policy.Read.All, Organization.Read.All
```

Links: [Microsoft Graph PowerShell](https://learn.microsoft.com/powershell/microsoftgraph/) ·
[PowerShell docs](https://learn.microsoft.com/powershell/) · [PowerShell Gallery](https://www.powershellgallery.com/)

## AD

| Script | What |
| --- | --- |
| `Get-StaleADComputers.ps1 -Days 90` | Enabled computers with no logon in 90 days |
| `Get-StaleADUsers.ps1 -Days 90` | Inactive, never-logged-on and password-never-expires users |
| `Get-ADPrivilegedMembers.ps1` | Members of the built-in admin groups, nested included |
| `Get-ADPasswordExpiry.ps1 -Days 14` | Passwords expiring in the next 14 days (honors FGPP) |
| `Get-ADLockoutSource.ps1 -Hours 4` | Lockouts from the PDC's 4740 events, with the caller computer |

## Entra ID

| Script | What | Scopes |
| --- | --- | --- |
| `Get-EntraAppCredentialExpiry.ps1 -Days 30` | App secrets and certs expiring soon | Application.Read.All |
| `Get-EntraMfaRegistration.ps1 -NotRegisteredOnly` | Users not registered for MFA (needs P1) | AuditLog.Read.All |
| `Get-EntraStaleGuests.ps1 -Days 90` | Guests not signed in for 90 days, or invite never accepted (needs P1) | User.Read.All, AuditLog.Read.All |
| `Export-EntraConditionalAccess.ps1` | All CA policies to JSON plus a summary CSV | Policy.Read.All |
| `Get-EntraLicenseUsage.ps1` | Purchased vs assigned per SKU | Organization.Read.All |

## Hybrid

| Script | What | Scopes |
| --- | --- | --- |
| `Get-HybridSyncStatus.ps1` | Last directory sync time and users with sync errors (duplicate UPN, proxyAddress) | Organization.Read.All, User.Read.All |
| `Compare-ADEntraUsers.ps1` | Enabled in AD but missing from Entra (out of sync scope), or disabled in AD but still enabled in Entra | User.Read.All + AD module |

On the Entra Connect server itself:

```powershell
Get-ADSyncScheduler                    # sync cycle settings, next run
Get-ADSyncConnectorRunStatus           # anything running right now
Start-ADSyncSyncCycle -PolicyType Delta
```

## Tests

`Invoke-Pester ./Tests`: every script parses, has help and an example, and passes PSScriptAnalyzer. Runs in GitHub Actions on each push.
