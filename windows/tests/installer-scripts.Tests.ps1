BeforeAll {
    $windowsRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallerPs1 = Join-Path $windowsRoot "install.ps1"
    $script:ReferenceInstallerPs1 = Join-Path $windowsRoot "openclaw\install.ps1"
}

Describe "Installer scripts parse and expose expected structure" {
    It "windows/install.ps1 parses without errors" {
        $tok = $null
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:InstallerPs1, [ref]$tok, [ref]$err) | Out-Null
        $err | Should -BeNullOrEmpty
    }

    It "windows/openclaw/install.ps1 parses without errors" {
        $tok = $null
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:ReferenceInstallerPs1, [ref]$tok, [ref]$err) | Out-Null
        $err | Should -BeNullOrEmpty
    }

    It "windows/install.ps1 contains onboard and skills flow" {
        $content = Get-Content -LiteralPath $script:InstallerPs1 -Raw
        $content.IndexOf("Invoke-OpenClawCommand onboard") | Should -BeGreaterThan -1
        $content.IndexOf("Install-Skills") | Should -BeGreaterThan -1
    }
}
