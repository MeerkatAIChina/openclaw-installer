BeforeAll {
    $windowsRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallerPs1 = Join-Path $windowsRoot "install.ps1"
    $script:ReferenceInstallerPs1 = Join-Path $windowsRoot "openclaw\install.ps1"
}

Describe "Windows installer script integrity" {
    It "defines Invoke-OpenClawCommand in main installer" {
        $content = Get-Content -LiteralPath $script:InstallerPs1 -Raw
        $content.IndexOf("function Invoke-OpenClawCommand") | Should -BeGreaterThan -1
    }

    It "defines Invoke-OpenClawDashboardBrowser in main installer" {
        $content = Get-Content -LiteralPath $script:InstallerPs1 -Raw
        $content.IndexOf("function Invoke-OpenClawDashboardBrowser") | Should -BeGreaterThan -1
    }

    It "reference installer still exists for comparison" {
        Test-Path -LiteralPath $script:ReferenceInstallerPs1 | Should -Be $true
    }
}
