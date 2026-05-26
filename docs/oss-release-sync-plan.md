# 阿里云 OSS 发布同步方案

## 一、背景与目标

当前 release 产物（`install-user-linux.sh`、`install-user-windows.ps1` 等）仅通过 GitHub Releases 分发。由于国内用户访问 GitHub 速度不稳定，需要在每次 release 时，将构建产物自动同步到阿里云上，提供一个国内可高速下载的渠道。

**目标**：打 tag → CI 构建 → GitHub Release + 阿里云 OSS 同步发布，用户可从 OSS 直链下载。

## 二、方案选型：阿里云 OSS

### 为什么选 OSS 而不是其他

| 方案 | 优点 | 缺点 |
|------|------|------|
| **OSS（对象存储）** ✅ | 官方 CLI、无需部署、自动 HTTP URL、按量付费、可绑 CDN | 需要配置 RAM 权限 |
| ECS + Nginx | 完全可控 | 需要维护服务器、成本高 |
| OSS + CDN | 下载最快 | 多了 CDN 配置，现阶段不需要 |
| 云效制品仓库 | 与流水线集成好 | 需要把整个 CI 迁移到云效，改动大 |

OSS 是最轻量的选择：**只增加一个上传步骤，不影响现有 GitHub Actions 流程**。

## 三、阿里云资源配置

### 1. 开通 OSS 服务

如果尚未开通，访问 [OSS 控制台](https://oss.console.aliyun.com) 按提示开通。开通服务本身免费。

参考：[控制台快速入门](https://help.aliyun.com/zh/oss/user-guide/console-quick-start)

### 2. 创建 OSS Bucket

登录 [OSS 控制台](https://oss.console.aliyun.com) → Bucket 列表 → 创建 Bucket：

| 参数 | 建议值 | 说明 |
|------|--------|------|
| Bucket 名称 | `meerkatai-claw` | 全局唯一，如已被占用可加随机后缀（如 `meerkatai-claw-hz01`） |
| 地域 | 华东1（杭州） | 选择离目标用户近的地域；创建后不可更改 |
| 存储类型 | 标准存储 | 默认选项 |
| 同城冗余存储 | 不开启 | 会增加存储费用，安装脚本不需要 |
| 读写权限 | **公共读** | 见下文注意事项 |
| 版本控制 | 不开启 | 按 tag 隔离即可，不需要版本控制 |
| 服务端加密 | 不开启 | 公开文件无需加密 |

#### ⚠️ 重要：关闭"阻止公共访问"

**从 2025 年 10 月起**，通过控制台创建 Bucket 时**默认开启阻止公共访问**，不允许直接在创建时将读写权限设为公共读。

正确做法：

1. 创建时读写权限选择「私有」（保持默认阻止公共访问）
2. 创建完成后，进入 Bucket → 数据安全 → 阻止公共访问
3. 关闭「阻止公共访问」，并确认风险提示
4. 回到 Bucket → 概览 → 读写权限 → 设置为「公共读」

创建完成后，Bucket 的默认外网访问域名为：

```
https://<bucket-name>.<region>.aliyuncs.com
```

例如：

```
https://meerkatai-claw.oss-cn-shanghai.aliyuncs.com
```

### 3. 公共读安全防护

阿里云官方**不建议**将 Bucket 直接设为公共读，主要风险是恶意刷流量导致高额账单。针对安装脚本分发场景（文件小、非敏感），公共读是合理的，但需要理解风险并做好监控。

#### 3.1 为什么不适合用防盗链

安装脚本的核心使用方式是通过 CLI 直接下载，这些请求**天然不带 Referer**：

```bash
# 所有主流 CLI 下载方式都不会发送 Referer 头
curl -fsSL <url> | bash       # Referer: 空
iwr -useb <url>               # Referer: 空
wget <url>                    # Referer: 空
```

如果在 OSS 防盗链中勾选「不允许空 Referer」，这些命令会全部返回 403。这与"让用户能直接下载安装脚本"的目标矛盾。

如果**不**勾选「不允许空 Referer」，则攻击者同样可以用空 Referer 发起请求，防盗链形同虚设。

**结论：对于安装脚本分发场景，OSS 防盗链不是合适的防护手段，不建议配置。**

#### 3.2 正确的防护策略：监控 + 限流

既然访问端不受控（任何人都能用 curl 下载），正确的思路是：**允许所有人访问，但实时监控，异常时快速响应。**

##### 3.2.1 云监控告警 —— 必须配置

进入云监控控制台，为 OSS 配置以下告警规则：

| 告警项 | 阈值 | 说明 |
|--------|------|------|
| 公网流出流量 | 1 GB / 小时 | 安装脚本单次下载不到 100KB，1 万次下载约 1GB，正常远达不到 |
| 请求次数（GetObject） | 10000 次 / 小时 | 超过此量级提示关注 |

##### 3.2.2 费用预算告警 —— 必须配置

进入阿里云费用中心，设置预算告警：

| 设置项 | 建议值 |
|--------|--------|
| 月度预算 | 10 元（安装脚本分发正常月费远低于此） |
| 告警阈值 | 预算的 80% |
| 通知方式 | 短信 + 邮件 |

##### 3.2.3 应急处理流程

如果收到告警：

1. 登录 OSS 控制台，查看实时监控确认是否异常
2. 确认异常后，临时将 Bucket 读写权限改为「私有」，阻断所有下载
3. 排查日志确认攻击来源和规模
4. 事后可考虑升级方案：接入 CDN 做频率控制，或将 Bucket 切回私有配合签名 URL

#### 3.3 后续可选的增强防护

| 方式 | 说明 | 适合时机 |
|------|------|----------|
| CDN + IP 限频 | Bucket 保持公共读，CDN 层配置单 IP QPS 限制（如 10 QPS），超出返回 429。保留了 CLI 下载能力，同时防刷 | 下载量起来后优先做 |
| CDN + 私有 Bucket 回源 | 安全性最高，但需要 CDN 鉴权配置 | 有明确安全需求时 |
| WAF 防护 | 绑定自定义域名后，接入 WAF 做 Bot 防护 | 自定义域名上线后 |

参考：[降低因恶意访问流量导致大额资金损失的风险](https://help.aliyun.com/zh/oss/user-guide/reduce-the-risks-of-unexpectedly-high-fees-caused-by-malicious-access-traffic) |

### 4. 创建 RAM 子账号

> 不要用主账号的 AccessKey。遵循最小权限原则。

**4.1 创建 RAM 用户**

[RAM 控制台](https://ram.console.aliyun.com) → 身份管理 → 用户 → 创建用户：

- 登录名称：`github-actions-oss`
- 显示名称：`GitHub Actions OSS Uploader`
- 访问方式：勾选「OpenAPI 调用访问」（生成 AccessKey）

**4.2 创建权限策略**

1. 进入 [RAM 控制台](https://ram.console.aliyun.com)
2. 左侧导航栏 → **权限管理** → **权限策略**
3. 点击 **创建权限策略**
4. 选择 **「脚本编辑」** 页签，粘贴以下 JSON 策略内容：

```json
{
    "Version": "1",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "oss:PutObject",
                "oss:GetObject",
                "oss:DeleteObject",
                "oss:ListObjects",
                "oss:GetBucketInfo"
            ],
            "Resource": [
                "acs:oss:*:*:<bucket-name>",
                "acs:oss:*:*:<bucket-name>/*"
            ]
        }
    ]
}
```

> 将 `<bucket-name>` 替换为实际 Bucket 名称（如 `meerkatai-claw`）。

1. 点击 **确定**，填写策略名称（如 `OSS-OpenClaw-Release-Upload`），保存

| Action | 用途 |
|--------|------|
| `oss:PutObject` | 上传文件 |
| `oss:GetObject` | 验证下载地址是否可访问（可选） |
| `oss:DeleteObject` | 覆盖旧版本时删除旧文件 |
| `oss:ListObjects` | 列出目录下文件（排查时有用） |
| `oss:GetBucketInfo` | 查询 Bucket 基本信息（排查时有用） |

**4.3 授权**

将上述策略绑定到 RAM 用户 `github-actions-oss`。

**4.4 保存 AccessKey**

创建完成后，保存 AccessKey ID 和 AccessKey Secret（Secret 只显示一次，务必备份）。

## 四、GitHub Secrets 配置

在仓库 `Settings` → `Secrets and variables` → `Actions` → `New repository secret`，添加以下 5 个 secrets：

| Secret 名称 | 值 | 说明 |
|---|---|---|
| `OSS_ENDPOINT` | `oss-cn-shanghai.aliyuncs.com` | OSS 地域 endpoint（不含 `https://`） |
| `OSS_REGION` | `cn-shanghai` | OSS 地域 ID，即 Bucket 所在地域的英文标识（v2 签名必填）。详见[地域与 Endpoint 文档](https://help.aliyun.com/zh/oss/user-guide/regions-and-endpoints) |
| `OSS_ACCESS_KEY_ID` | `LTAI5tXXXXXXXXXXXXXX` | RAM 用户的 AccessKey ID |
| `OSS_ACCESS_KEY_SECRET` | `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx` | RAM 用户的 AccessKey Secret |
| `OSS_BUCKET` | `meerkatai-claw` | Bucket 名称 |

> ossutil v2 使用 V4 签名，`region` 为必填项。若未配置会报错 "region must be set in sign version 4"。

## 五、Workflow 改动

修改 `.github/workflows/release.yml`，在 `gh release create` 之后新增一个 step。

### 5.1 改动后的完整 workflow

```yaml
name: Release

on:
  push:
    tags:
      - "v*"

permissions:
  contents: write

jobs:
  build-and-release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"

      - name: Install PowerShell
        run: |
          set -euo pipefail
          sudo apt-get update
          sudo apt-get install -y wget apt-transport-https software-properties-common
          . /etc/os-release
          wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
          sudo dpkg -i /tmp/packages-microsoft-prod.deb
          sudo apt-get update
          sudo apt-get install -y powershell
          pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'

      - name: Install shfmt
        run: |
          set -e
          curl -fsSL -o /tmp/shfmt https://github.com/mvdan/sh/releases/download/v3.13.1/shfmt_v3.13.1_linux_amd64
          sudo install -m 0755 /tmp/shfmt /usr/local/bin/shfmt
          shfmt -version

      - name: Build dist/
        run: node scripts/build-release.cjs

      - name: Verify shell dist scripts
        run: |
          set -e
          shopt -s nullglob
          for f in dist/*.sh; do
            echo "bash -n $f"
            bash -n "$f"
          done

      - name: Verify PowerShell dist scripts
        shell: pwsh
        run: pwsh -NoProfile -File scripts/verify-dist-ps1-parse.ps1

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          tag="${GITHUB_REF_NAME:?}"
          ls -la dist/
          gh release create "$tag" --generate-notes dist/*

      - name: Upload to Alibaba Cloud OSS
        env:
          OSS_ACCESS_KEY_ID: ${{ secrets.OSS_ACCESS_KEY_ID }}
          OSS_ACCESS_KEY_SECRET: ${{ secrets.OSS_ACCESS_KEY_SECRET }}
          OSS_REGION: ${{ secrets.OSS_REGION }}
          OSS_ENDPOINT: ${{ secrets.OSS_ENDPOINT }}
          OSS_BUCKET: ${{ secrets.OSS_BUCKET }}
        run: |
          set -euo pipefail
          tag="${GITHUB_REF_NAME:?}"

          # 下载安装 ossutil v2（当前最新版本 2.3.0）
          OSSUTIL_URL="https://gosspublic.alicdn.com/ossutil/v2/2.3.0/ossutil-2.3.0-linux-amd64.zip"
          curl -fsSL -o /tmp/ossutil.zip "$OSSUTIL_URL"
          unzip -o /tmp/ossutil.zip -d /tmp/ossutil
          chmod +x /tmp/ossutil/ossutil

          # 通过环境变量配置认证（ossutil v2 支持，优先级高于配置文件）
          # 无需跑 ossutil config，环境变量已足够

          # 上传 dist/ 到 oss://<bucket>/releases/<tag>/
          /tmp/ossutil/ossutil cp -r -f -e "$OSS_ENDPOINT" dist/ "oss://${OSS_BUCKET}/scripts/${tag}/"

          # 打印下载链接供验证
          echo "=== OSS 下载地址 ==="
          for f in dist/*; do
            filename="$(basename "$f")"
            echo "https://${OSS_BUCKET}.${OSS_ENDPOINT}/scripts/${tag}/${filename}"
          done
```

### 5.2 改动要点

| 项目 | 说明 |
|------|------|
| ossutil 版本 | **v2.3.0**（v1 已过时），下载链接格式为 `gosspublic.alicdn.com/ossutil/v2/<version>/ossutil-<version>-linux-amd64.zip` |
| 认证方式 | 使用**环境变量**（`OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET`、`OSS_REGION`），优于交互式 `ossutil config`，更适合 CI 环境 |
| `-e` 参数 | 命令行显式指定 Endpoint，覆盖环境变量，确保指向正确地址 |
| V4 签名 | ossutil v2 使用 V4 签名，`region` 为**必填项**，需通过 `OSS_REGION` 环境变量或 `--region` 参数指定 |
| 目录结构 | `oss://<bucket>/releases/<tag>/`，按 tag 隔离，不会互相覆盖 |
| `-f` / `-r` | 强制覆盖（幂等）、递归上传 |
| SHA256 校验 | ossutil v2 发布包提供 SHA256 校验和，如需可在 workflow 中增加校验步骤 |

下载链接参考：[ossutil 概览](https://help.aliyun.com/zh/oss/developer-reference/ossutil-overview)

## 六、用户下载方式

上传完成后，用户可以通过以下格式的 URL 直接下载：

```
https://<bucket>.<endpoint>/releases/<tag>/<filename>
```

具体示例：

```bash
# Linux / macOS
curl -fsSL https://meerkatai-claw.oss-cn-shanghai.aliyuncs.com/releases/v1.0.0/install-user-linux.sh | bash

# Windows PowerShell
iwr -useb 'https://meerkatai-claw.oss-cn-shanghai.aliyuncs.com/releases/v1.0.0/install-user-windows.ps1' -OutFile $env:TEMP\oc.ps1
```

如果后期绑定自定义域名（如 `dl.openclaw.cn`），URL 会更简洁：

```
https://dl.openclaw.cn/releases/v1.0.0/install-user-linux.sh
```

## 七、成本估算

| 项目 | 单价（华东1） | 估算 |
|------|-------------|------|
| 存储空间 | 0.12 元/GB/月 | 每版本 ~200KB，100 个版本仅 20MB，几乎为零 |
| 外网流出流量 | 0.25 元/GB（闲时） ~ 0.50 元/GB（忙时） | 每 1 万次下载约 0.5 元 |

**结论**：在正常下载量下，月费用基本在几分钱到几毛钱，可以忽略不计。

**风险提示**：唯一需要注意的是恶意刷流量。如果被人发现 URL 规律并大量请求，理论上会产生费用。建议配置第三章节中的监控告警来防范。

## 八、后续优化方向

| 优化项 | 说明 | 优先级 |
|--------|------|--------|
| 云监控 + 预算告警 | 见 3.2 节，实施前必须配置 | **高（上线前必做）** |
| 最新版快捷链接 | 上传时额外覆盖一份到 `oss://bucket/releases/latest/`，用户无需知道具体版本号 | 中 |
| 绑定自定义域名 | 使用 `dl.openclaw.cn` 等域名，隐藏 OSS 原始地址，提升品牌感 | 中 |
| CDN + IP 限频 | CDN 层配置单 IP QPS 限制，保留 CLI 下载能力的同时防刷 | 中（量起来后优先做） |
| CDN + 私有 Bucket 回源 | 安全性最高，但会改变访问方式 | 低 |
| 版本列表页 | 在 OSS 开启静态网站托管，生成版本目录索引 | 低 |
