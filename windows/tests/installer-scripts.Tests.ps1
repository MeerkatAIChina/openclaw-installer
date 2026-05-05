BeforeAll {
    $windowsRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallerPs1 = Join-Path $windowsRoot "node\node-installer.ps1"
    $script:UninstallerPs1 = Join-Path $windowsRoot "node\node-uninstaller.ps1"
    $script:PathUtilsPs1 = Join-Path $windowsRoot "node\path-utils.ps1"
}

Describe "Installer scripts parse and expose expected structure" {
    It "node-installer.ps1 parses without errors" {
        $tok = $null
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:InstallerPs1, [ref]$tok, [ref]$err) | Out-Null
        $err | Should -BeNullOrEmpty
    }

    It "node-uninstaller.ps1 parses without errors" {
        $tok = $null
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:UninstallerPs1, [ref]$tok, [ref]$err) | Out-Null
        $err | Should -BeNullOrEmpty
    }

    It "path-utils.ps1 parses without errors" {
        $tok = $null
        $err = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:PathUtilsPs1, [ref]$tok, [ref]$err) | Out-Null
        $err | Should -BeNullOrEmpty
    }

    It "installer dot-sources path-utils before using helpers" {
        $content = Get-Content -LiteralPath $script:InstallerPs1 -Raw
        $idxDot = $content.IndexOf("path-utils.ps1")
        $idxInstallDir = $content.IndexOf("Get-ProgramFilesNodeInstallRoot")
        $idxDot | Should -Not -Be -1
        $idxInstallDir | Should -Not -Be -1
        $idxDot | Should -BeLessThan $idxInstallDir
    }
}
