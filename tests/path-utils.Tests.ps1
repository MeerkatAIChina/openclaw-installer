BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    . (Join-Path $repoRoot "windows\path-utils.ps1")
    $script:backupUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
}

AfterAll {
    if ($null -ne $script:backupUserPath) {
        [Environment]::SetEnvironmentVariable("Path", $script:backupUserPath, "User")
    }
}

Describe "Get-ProgramFilesNodeInstallRoot" {
    It "returns an existing directory path" {
        $r = Get-ProgramFilesNodeInstallRoot
        $r | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath $r | Should -Be $true
    }
}

Describe "Add-PathEntryIfMissing" {
    BeforeEach {
        $script:testEntry = Join-Path $env:TEMP ("oc-path-" + [guid]::NewGuid().ToString("N"))
    }

    AfterEach {
        Remove-PathEntryIfExists -Scope User -Entry $script:testEntry
    }

    It "appends a missing entry to User Path" {
        Add-PathEntryIfMissing -Scope User -Entry $script:testEntry
        $p = [Environment]::GetEnvironmentVariable("Path", "User")
        ($p -split ";" | Where-Object { $_ -eq $script:testEntry }).Count | Should -Be 1
    }

    It "does not duplicate the same logical path" {
        Add-PathEntryIfMissing -Scope User -Entry $script:testEntry
        Add-PathEntryIfMissing -Scope User -Entry ($script:testEntry + "\")
        $p = [Environment]::GetEnvironmentVariable("Path", "User")
        $matches = $p -split ";" | Where-Object {
            $_.TrimEnd("\").ToLowerInvariant() -eq $script:testEntry.TrimEnd("\").ToLowerInvariant()
        }
        $matches.Count | Should -Be 1
    }
}

Describe "Remove-PathEntryIfExists" {
    BeforeEach {
        $script:testEntry = Join-Path $env:TEMP ("oc-path-" + [guid]::NewGuid().ToString("N"))
        Add-PathEntryIfMissing -Scope User -Entry $script:testEntry
    }

    It "removes an existing entry" {
        Remove-PathEntryIfExists -Scope User -Entry $script:testEntry
        $p = [Environment]::GetEnvironmentVariable("Path", "User")
        ($p -split ";" | Where-Object { $_ -eq $script:testEntry }).Count | Should -Be 0
    }
}
