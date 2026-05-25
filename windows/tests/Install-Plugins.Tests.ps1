# windows/tests/Install-Plugins.Tests.ps1
Describe "Install-Plugins" {
    BeforeAll {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "../..")
        $scriptPath = Join-Path $repoRoot "windows/install-user-dev.ps1"

        # 防止 dot-source 后执行 dashboard 代码
        $NoDashboard = $true

        # 读取脚本内容，替换 Main 调用行防止 dot-source 时执行 Main
        $scriptContent = Get-Content $scriptPath -Raw
        $scriptContent = $scriptContent -replace '\$mainResults\s*=\s*@\(Main\)',
            '$mainResults = @($true)'

        # Dot-source 修改后的脚本以载入所有函数定义
        . ([scriptblock]::Create($scriptContent)) *> $null

        # 现在函数已定义，可以 Mock 它们供测试 Install-Plugins 使用
        Mock Invoke-OpenClawCommand { return $true } -Verifiable
        Mock Get-OpenClawCommandPath { return "openclaw" }
    }

    Context "函数存在性" {
        It "Install-Plugins 函数已定义" {
            { Get-Command Install-Plugins -ErrorAction Stop } | Should -Not -Throw
        }
    }

    Context "默认插件列表" {
        It "包含 @meerkat-ai/openclaw-mrkhub-plugin" {
            Install-Plugins

            Should -Invoke Invoke-OpenClawCommand -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'npm:@meerkat-ai/openclaw-mrkhub-plugin'
            }
        }
    }

    Context "单个插件安装失败不中断" {
        It "失败后继续安装后续插件并报告失败数量" {
            Mock Invoke-OpenClawCommand {
                $global:LASTEXITCODE = 1
            }

            Install-Plugins

            Should -Invoke Invoke-OpenClawCommand -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'npm:@meerkat-ai/openclaw-mrkhub-plugin'
            }
        }
    }

    Context "全部安装成功" {
        It "退出码为 0 时输出成功信息" {
            Mock Invoke-OpenClawCommand {
                $global:LASTEXITCODE = 0
            }

            Install-Plugins

            Should -Invoke Invoke-OpenClawCommand -Times 1 -Exactly -ParameterFilter {
                $Arguments -contains 'npm:@meerkat-ai/openclaw-mrkhub-plugin'
            }
        }
    }
}
