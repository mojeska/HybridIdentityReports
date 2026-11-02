<#
.SYNOPSIS
Runs every report script against a real AD domain and/or Entra ID tenant and records how each one did.
.DESCRIPTION
For lab testing before a release. Each script is run with its defaults; the runner records
Pass/Fail/Skipped, the row count, how long it took, any errors, and columns that came back
empty in every row (usually a wrong property name). Each script's output is saved as a CSV.

Read-only, like the scripts. The output folder holds user names from the directory, so keep
it out of git (LiveTest-* is in .gitignore).

AD scripts need the ActiveDirectory module (domain-joined machine). Entra ID scripts need
Connect-MgGraph first. Hybrid\Compare-ADEntraUsers needs both in the same session.
.EXAMPLE
Connect-MgGraph -Scopes User.Read.All, AuditLog.Read.All, Application.Read.All, Policy.Read.All, Organization.Read.All
.\Tests\Invoke-LiveTest.ps1
.EXAMPLE
.\Tests\Invoke-LiveTest.ps1 -Area AD -OutPath C:\Temp\hir-test
#>
[CmdletBinding()]
param(
    [ValidateSet('All', 'AD', 'EntraID', 'Hybrid')]
    [string]$Area = 'All',
    [string]$OutPath = ".\LiveTest-$([Environment]::MachineName)-$(Get-Date -Format yyyyMMdd-HHmm)"
)

$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Path $OutPath -Force | Out-Null

$hasAD = [bool](Get-Module -ListAvailable ActiveDirectory)
$mg = if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) { Get-MgContext }
$hasGraph = [bool]$mg

# Script, extra arguments, what it needs
$cases = @(
    @{ Script = 'AD\Get-StaleADComputers.ps1';           Needs = 'AD' }
    @{ Script = 'AD\Get-StaleADUsers.ps1';               Needs = 'AD' }
    @{ Script = 'AD\Get-ADPrivilegedMembers.ps1';        Needs = 'AD' }
    @{ Script = 'AD\Get-ADPasswordExpiry.ps1';           Needs = 'AD'; Args = @{ Days = 365 } }
    @{ Script = 'AD\Get-ADLockoutSource.ps1';            Needs = 'AD'; Args = @{ Hours = 720 } }
    @{ Script = 'EntraID\Get-EntraAppCredentialExpiry.ps1'; Needs = 'Graph'; Args = @{ Days = 3650 } }
    @{ Script = 'EntraID\Get-EntraMfaRegistration.ps1';  Needs = 'Graph' }
    @{ Script = 'EntraID\Get-EntraStaleGuests.ps1';      Needs = 'Graph' }
    @{ Script = 'EntraID\Export-EntraConditionalAccess.ps1'; Needs = 'Graph'; Args = @{ Path = (Join-Path $OutPath 'ConditionalAccess') } }
    @{ Script = 'EntraID\Get-EntraLicenseUsage.ps1';     Needs = 'Graph' }
    @{ Script = 'Hybrid\Get-HybridSyncStatus.ps1';       Needs = 'Graph' }
    @{ Script = 'Hybrid\Compare-ADEntraUsers.ps1';       Needs = 'AD+Graph' }
)

Write-Host "Host: $([Environment]::MachineName)   AD module: $hasAD   Graph: $(if ($mg) { "$($mg.Account) @ $($mg.TenantId)" } else { 'not connected' })"
if ($mg) { Write-Host "Scopes: $($mg.Scopes -join ', ')" }

$results = foreach ($c in $cases) {
    $areaName = ($c.Script -split '[\\/]')[0]
    if ($Area -ne 'All' -and $areaName -ne $Area) { continue }

    $path = Join-Path $root ($c.Script -replace '\\', [IO.Path]::DirectorySeparatorChar)
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    $scriptArgs = if ($c.Args) { $c.Args } else { @{} }

    $missing = switch ($c.Needs) {
        'AD'       { if (-not $hasAD) { 'ActiveDirectory module' } }
        'Graph'    { if (-not $hasGraph) { 'Connect-MgGraph' } }
        'AD+Graph' { @(if (-not $hasAD) { 'ActiveDirectory module' }; if (-not $hasGraph) { 'Connect-MgGraph' }) -join ' + ' }
    }
    if ($missing) {
        [pscustomobject]@{ Script = $name; Status = 'Skipped'; Rows = $null; Seconds = $null; EmptyColumns = $null; Notes = "needs $missing" }
        continue
    }

    Write-Host "Running $name ..." -NoNewline
    $ev = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $out = @(& $path @scriptArgs -ErrorVariable ev -WarningVariable wv)
        $fatal = $null
    }
    catch { $out = @(); $fatal = $_ }
    $sw.Stop()

    # Format-* output can't be exported or piped on; flag it
    $formatObjs = @($out | Where-Object { $_ -and $_.GetType().FullName -like 'Microsoft.PowerShell.Commands.Internal.Format.*' })
    $rows = @($out | Where-Object { $_ -is [psobject] -and $_ -isnot [string] -and $_.GetType().FullName -notlike 'Microsoft.PowerShell.Commands.Internal.Format.*' })
    $strings = @($out | Where-Object { $_ -is [string] })

    $empty = @()
    if ($rows.Count -gt 1) {
        $empty = @($rows[0].PSObject.Properties.Name | Where-Object {
            $p = $_; -not ($rows | Where-Object { $null -ne $_.$p -and "$($_.$p)" -ne '' })
        })
    }
    if ($rows) { $rows | Export-Csv (Join-Path $OutPath "$name.csv") -NoTypeInformation }

    $notes = @(
        if ($fatal) { "TERMINATING: $($fatal.Exception.Message)" }
        $ev | ForEach-Object { "ERROR: $($_.Exception.Message)" } | Select-Object -Unique
        $wv | ForEach-Object { "WARNING: $_" } | Select-Object -Unique
        if ($formatObjs) { "emits $($formatObjs.Count) Format-* objects (not exportable)" }
        $strings | ForEach-Object { "text: $_" }
    )
    $status = if ($fatal -or $ev) { 'Fail' } else { 'Pass' }
    Write-Host " $status ($($rows.Count) rows, $([math]::Round($sw.Elapsed.TotalSeconds, 1)) s)"

    [pscustomobject]@{
        Script       = $name
        Status       = $status
        Rows         = $rows.Count
        Seconds      = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        EmptyColumns = $empty -join ', '
        Notes        = $notes -join ' | '
    }
}

$results | Export-Csv (Join-Path $OutPath 'summary.csv') -NoTypeInformation
Write-Host "`nResults in $((Resolve-Path $OutPath).Path)"
$results
