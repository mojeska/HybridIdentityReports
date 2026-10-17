# Every script parses, has a synopsis and an example, and passes PSScriptAnalyzer.

BeforeDiscovery {
    $root = Split-Path $PSScriptRoot -Parent
    $scripts = Get-ChildItem $root -Recurse -Filter *.ps1 |
        Where-Object { $_.DirectoryName -notlike '*Tests*' } |
        ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } }
}

Describe '<Name>' -ForEach $scripts {
    It 'parses without errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors) | Out-Null
        $errors | Should -BeNullOrEmpty
    }
    It 'has a synopsis and an example' {
        $help = Get-Help $Path -Full
        $help.Synopsis | Should -Not -BeNullOrEmpty
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
    }
    It 'passes PSScriptAnalyzer' {
        $issues = Invoke-ScriptAnalyzer -Path $Path -Severity Warning, Error
        $issues | ForEach-Object { Write-Host "$($_.Line) $($_.RuleName) $($_.Message)" }
        $issues | Should -BeNullOrEmpty
    }
}
