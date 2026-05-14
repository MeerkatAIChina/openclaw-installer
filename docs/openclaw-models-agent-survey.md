# OpenClaw `models` / `agents` 及相关根配置调研

> 依据 [OpenClaw 官方文档](https://documentation.openclaw.ai/) 与上游仓库 Zod Schema（`openclaw/openclaw`）整理；配置格式为 JSON5。字段均可选，省略时使用运行时默认。  
> **校验**：本仓库环境未检测到 `openclaw` CLI，未执行 `openclaw config schema`；完整机器可读约束请以 `openclaw config schema` 或源码 Schema 为准。

---

## 一、Models

### 1.1 顶层 `models`

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `models.mode` | 自定义提供商目录与内置目录的合并策略 | `merge` / `replace` | 未设置（等价 merge） | `openclaw config set models.mode …` |
| `models.pricing.enabled` | 是否在 Gateway 就绪后拉取 OpenRouter/LiteLLM 等定价目录（后台） | `true` / `false` | `true`（文档示例可显式关闭） | `openclaw config set models.pricing.enabled …` |
| `models.providers` | 自定义提供商映射（键为 provider id） | 对象，键为字符串 | 未设置 | `openclaw configure --section model` / `openclaw config set models.providers… --strict-json --merge` |
| `models.providers.<id>` | 单个提供商连接与模型列表 | 见 1.2 | 未设置 | 同上 |

**说明（废弃别名）**：类型定义 `ModelsConfig` 中仍存在 `bedrockDiscovery` / `copilotDiscovery` / `huggingfaceDiscovery` / `ollamaDiscovery` 等 **deprecated** 根字段供旧配置迁移；当前 `ModelsConfigSchema` 严格对象未包含这些键，若需迁移请运行 `openclaw doctor --fix`（见官方文档）。

### 1.2 `models.providers.<providerId>`（提供商块）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `models.providers.<id>.baseUrl` | OpenAI 兼容或其它 HTTP API 根地址 | URL 字符串 | 必填（Schema 要求 `.min(1)`） | `openclaw config set …` |
| `models.providers.<id>.apiKey` | 提供商 API Key（支持 SecretRef） | 字符串 / SecretRef | 未设置 | `openclaw models auth paste-token --provider <id>`（视提供商）/ `config set` |
| `models.providers.<id>.auth` | 鉴权模式 | `api-key` / `aws-sdk` / `oauth` / `token` | 未设置 | `openclaw models auth login --provider <id>` |
| `models.providers.<id>.api` | 使用的协议/API 族 | 见脚注「ModelApi」 | 未设置 | `config set` |
| `models.providers.<id>.contextWindow` | 提供商级默认上下文窗口（token） | 正数 | 未设置 | `config set` |
| `models.providers.<id>.contextTokens` | 运行时有效上下文 cap | 正整数 | 未设置 | `config set` |
| `models.providers.<id>.maxTokens` | 提供商级默认单次生成上限 | 正数 | 未设置 | `config set` |
| `models.providers.<id>.timeoutSeconds` | HTTP 请求超时（秒） | 正整数 | 未设置 | `config set` |
| `models.providers.<id>.injectNumCtxForOpenAICompat` | 是否为 OpenAI 兼容请求注入 `num_ctx` 类字段 | `true` / `false` | 未设置 | `config set` |
| `models.providers.<id>.params` | 提供商级透传参数（插件解释） | 任意 JSON 对象 | 未设置 | `config set … --merge` |
| `models.providers.<id>.agentRuntime` | 该提供商默认执行运行时 | `{ id?: string }` | 未设置 | `config set` |
| `models.providers.<id>.localService` | 本地/自托管服务拉起配置 | 见 1.5 | 未设置 | 见 [Local model services](https://documentation.openclaw.ai/gateway/local-model-services) |
| `models.providers.<id>.headers` | 额外请求头 | `Record<string, SecretInput>` | 未设置 | `config set` |
| `models.providers.<id>.authHeader` | 是否附加标准鉴权头 | `true` / `false` | 未设置 | `config set` |
| `models.providers.<id>.request` | 高级 TLS/代理/私网访问等 | 见 1.4 | 未设置 | `config set` |
| `models.providers.<id>.models` | 模型定义数组 | `ModelDefinition[]` | 必填数组（Schema） | `config set` |

**contextWindow、contextTokens、maxTokens 的说明**

| 字段            | 含义                                                         | 典型用途                                                     |
| :-------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| `contextWindow` | 模型/提供商的上下文窗口规模（token 数，偏「能力/目录」描述） | 标明该模型理论上能容纳多少上下文（输入侧窗口上限的元数据）。 |
| `contextTokens` | 运行时对上下文的 cap（封顶）                                 | OpenClaw 在跑的时候按这个预算限制「有效上下文」，可故意设得比 `contextWindow` 小，用于控成本、控延迟或与 Agent 侧 `agents.defaults.contextTokens` 等一起收紧。 |
| `maxTokens`     | 单次生成（模型回复）的 token 上限                            | 对应「这一枪最多生成多少 token」，偏输出长度/API 的 `max_tokens` 类默认，不是「整段对话窗口有多大」。 |

### 1.3 `models.providers.<id>.models[]`（单模型定义）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `…models[].id` | 模型 id（与 provider 组合成 `provider/id`） | 非空字符串 | 必填 | `openclaw models set <provider>/<id>`（间接） |
| `…models[].name` | 展示名 | 非空字符串 | 必填 | 无 |
| `…models[].api` | 覆盖提供商默认 API 族 | 见「ModelApi」 | 未设置 | `config set` |
| `…models[].baseUrl` | 单模型覆盖 baseUrl | URL | 未设置 | `config set` |
| `…models[].reasoning` | 是否支持推理类负载 | `true` / `false` | 未设置 | `config set` |
| `…models[].input` | 支持的模态 | `text` / `image` / `video` / `audio` 数组 | 未设置 | `config set` |
| `…models[].cost.input` | 输入单价（USD/百万 token 等，见插件） | 数 | 未设置 | `config set` |
| `…models[].cost.output` | 输出单价 | 数 | 未设置 | `config set` |
| `…models[].cost.cacheRead` | 缓存读单价 | 数 | 未设置 | `config set` |
| `…models[].cost.cacheWrite` | 缓存写单价 | 数 | 未设置 | `config set` |
| `…models[].cost.tieredPricing[]` | 分层计价 | `{input,output,cacheRead,cacheWrite,range}` | 未设置 | `config set` |
| `…models[].contextWindow` | 模型上下文窗口 | 正数 | 未设置（类型默认 200000 为类型层说明，非 Zod 默认） | `config set` |
| `…models[].contextTokens` | 运行时 cap | 正整数 | 未设置 | `config set` |
| `…models[].maxTokens` | 单次生成 token 上限 | 正数 | 未设置 | `config set` |
| `…models[].params` | 模型级透传参数 | 对象 | 未设置 | `config set … --merge` |
| `…models[].agentRuntime` | 模型级运行时策略 | `{ id?: string }` | 未设置 | `config set` |
| `…models[].headers` | 模型级请求头 | `Record<string,string>` | 未设置 | `config set` |
| `…models[].compat` | OpenAI/Anthropic 等兼容开关集合 | 见脚注「Compat」 | 未设置 | `config set` |
| `…models[].metadataSource` | 元数据来源标记 | `models-add` | 未设置 | 无 |

### 1.4 `models.providers.<id>.request`（TLS / 代理 / 私网）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `…request.allowPrivateNetwork` | 是否允许访问 RFC1918 等私网地址 | `true` / `false` | 未设置 | `config set` |
| `…request.headers` | 每请求附加头 | 对象 | 未设置 | `config set` |
| `…request.auth` | 请求级 mTLS 等 | `cert`+`key` / `token` 等子形状 | 未设置 | `config set` |
| `…request.proxy` | HTTP(S) 代理 | `url` / `explicit-proxy` 对象 | 未设置 | `config set` |
| `…request.tls` | CA/客户端证书等 | `ca`/`cert`/`key`/… | 未设置 | `config set` |

### 1.5 `models.providers.<id>.localService`

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `…localService.command` | 启动本地推理服务的可执行文件 | 绝对路径字符串 | 未设置 | 无 |
| `…localService.args` | 参数列表 | 字符串数组 | 未设置 | 无 |
| `…localService.cwd` | 工作目录 | 路径 | 未设置 | 无 |
| `…localService.env` | 子进程环境变量 | 对象 | 未设置 | 无 |
| `…localService.healthUrl` | 健康检查 URL | URL | 未设置 | 无 |
| `…localService.readyTimeoutMs` | 就绪等待毫秒 | 正整数 | 未设置 | 无 |
| `…localService.idleStopMs` | 空闲停止毫秒；`0` 表示保持 | 非负整数 | 未设置 | 无 |

### 1.6 与 Models 强相关、位于 `agents` 的配置（交叉索引）

以下键在 JSON 中属于 `agents.defaults` / `agents.list[]`，但语义为 **模型选择与目录**，详细参数表见 **第二章**对应行。

| 路径 | 说明 |
|------|------|
| `agents.defaults.model` | 主模型与回退链 |
| `agents.defaults.imageModel` / `pdfModel` / `imageGenerationModel` / `videoGenerationModel` / `musicGenerationModel` | 多模态与媒体路由 |
| `agents.defaults.models` | `/model` 允许列表 + `alias` / `params` / `agentRuntime` / `streaming` |
| `agents.defaults.params` | 全局默认 provider 参数（合并到所有模型） |
| `agents.defaults.contextTokens` | Agent 级运行时上下文预算 |

### 1.7 `models` 完整示例（JSON5 + 行尾注释）

```json5
{
  models: {
    mode: "merge", // merge=与内置目录合并；replace=仅使用下列自定义 providers
    pricing: { enabled: true }, // false 可跳过定价目录后台拉取
    providers: {
      lmstudio: {
        baseUrl: "http://127.0.0.1:1234/v1",
        apiKey: "${LM_API_TOKEN}", // 支持 env 展开；也可用 SecretRef
        api: "openai-completions",
        timeoutSeconds: 300,
        contextWindow: 128000,
        maxTokens: 8192,
        injectNumCtxForOpenAICompat: false,
        request: { allowPrivateNetwork: true }, // 仅当 baseUrl 解析到私网时需要显式 opt-in
        models: [
          {
            id: "my-local-chat",
            name: "Local Chat",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 128000,
            maxTokens: 8192,
            // compat / params 可按代理能力补充；未列出字段见 Schema
          },
          {
            id: "my-local-vision",
            name: "Local Vision",
            reasoning: false,
            input: ["text", "image"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 128000,
            maxTokens: 4096,
          },
        ],
      },
    },
  },
  agents: {
    defaults: {
      // 与上列 models 中 id 对齐：provider/model
      model: { primary: "lmstudio/my-local-chat", fallbacks: [] },
      models: {
        "lmstudio/my-local-chat": { alias: "local" },
        "lmstudio/my-local-vision": { alias: "local-vision" },
      },
    },
  },
}
```

### 1.8 Models：CLI 速查

| 命令 | 用途 |
|------|------|
| `openclaw models` | 等价 `models status` |
| `openclaw models status [--json] [--probe] [--agent <id>]` | 当前默认模型、回退、鉴权概览 |
| `openclaw models list [--all] [--provider <id>] [--json]` | 列出可用/发现模型 |
| `openclaw models set <provider/model>` | 写入 `agents.defaults.model.primary` |
| `openclaw models set-image <provider/model>` | 设置图像模型 |
| `openclaw models scan …` | OpenRouter 免费目录扫描（可选 `--set-default`） |
| `openclaw models auth add|list|login|setup-token|paste-token` | 鉴权配置 |
| `openclaw models aliases list|add|remove` | 别名 |
| `openclaw models fallbacks list|add|remove|clear` | 文本回退链 |
| `openclaw models image-fallbacks list|add|remove|clear` | 图像回退链 |
| `openclaw config get|set models…` | 直接读写 `models.*` 任意路径 |
| `openclaw configure --section model` | 交互向导 |

**脚注 — ModelApi**：`openai-completions` / `openai-responses` / `openai-codex-responses` / `anthropic-messages` / `google-generative-ai` / `github-copilot` / `bedrock-converse-stream` / `ollama` / `azure-openai-responses`（源码 `src/config/types.models.ts`）。

**脚注 — Compat（节选）**：`supportsStore`、`supportsDeveloperRole`、`supportsReasoningEffort`、`thinkingFormat`、`supportedReasoningEfforts`、`reasoningEffortMap`、`maxTokensField` 等；完整列表见 `ModelCompatSchema`（`zod-schema.core.ts`）。

---

## 二、Agent

### 2.1 `agents.defaults`（默认值）

#### 2.1.1 模型与流参数

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.defaults.model` | 主模型：字符串或 `{primary,fallbacks?,timeoutMs?}` | `provider/model` | 未设置 | `openclaw models set …` / `config set` |
| `agents.defaults.imageModel` | 视觉/图像理解模型路由 | 同上 | 未设置 | `openclaw models set-image …` |
| `agents.defaults.pdfModel` | PDF 工具模型 | 同上 | 未设置 | `config set` |
| `agents.defaults.imageGenerationModel` | 文生图模型 | 同上 | 未设置 | `config set` |
| `agents.defaults.videoGenerationModel` | 视频生成模型 | 同上 | 未设置 | `config set` |
| `agents.defaults.musicGenerationModel` | 音乐生成模型 | 同上 | 未设置 | `config set` |
| `agents.defaults.mediaGenerationAutoProviderFallback` | 媒体生成是否自动提供商回退 | `true` / `false` | 未设置 | `config set` |
| `agents.defaults.pdfMaxBytesMb` | PDF 默认大小上限（MB） | 正数 | `10`（文档示例） | `config set` |
| `agents.defaults.pdfMaxPages` | PDF 最大页数 | 正整数 | `20`（文档示例） | `config set` |
| `agents.defaults.models` | 模型目录/allowlist；值含 `alias`/`params`/`agentRuntime`/`streaming` | `Record<provider/model, object>` | 未设置 | `openclaw config set agents.defaults.models '…' --strict-json --merge` |
| `agents.defaults.params` | 全局 provider 参数（合并到所有模型前） | 对象 | 未设置 | `config set … --merge` |
| `agents.defaults.contextTokens` | Agent 级运行时上下文 cap | 正整数 | 未设置（文档大示例 `200000`） | `config set` |
| `agents.defaults.thinkingDefault` | 默认 thinking 等级 | `off`/`minimal`/`low`/`medium`/`high`/`xhigh`/`adaptive`/`max` | 未设置 | `config set` |
| `agents.defaults.verboseDefault` | 默认 verbose | `off`/`on`/`full` | `off` | `config set` |
| `agents.defaults.toolProgressDetail` | 工具进度展示 | `explain` / `raw` | `explain` | `config set` |
| `agents.defaults.reasoningDefault` | 推理可见性默认 | `off`/`on`/`stream` | 未设置 | `config set` |
| `agents.defaults.elevatedDefault` | 提升输出默认 | `off`/`on`/`ask`/`full` | `on` | `config set` |
| `agents.defaults.blockStreamingDefault` | 块流式默认 | `on` / `off` | 未设置 | `config set` |
| `agents.defaults.blockStreamingBreak` | 块边界 | `text_end` / `message_end` | 未设置 | `config set` |
| `agents.defaults.blockStreamingChunk` | 块大小策略 | `{minChars,maxChars}` 等 | 未设置 | `config set` |
| `agents.defaults.blockStreamingCoalesce` | 块合并空闲窗口 | `{idleMs}` 等 | 未设置 | `config set` |
| `agents.defaults.humanDelay` | 块间随机延迟 | `off`/`natural`/`custom`+ms | 未设置 | `config set` |
| `agents.defaults.timeoutSeconds` | Agent 单次运行超时（秒） | 正整数 | 未设置（文档示例 `600`） | `config set` |
| `agents.defaults.mediaMaxMb` | 媒体大小上限（MB） | 正数 | 未设置（文档示例 `5`） | `config set` |
| `agents.defaults.imageMaxDimensionPx` | 图像最长边缩放像素 | 正整数 | `1200` | `config set` |
| `agents.defaults.typingMode` | 正在输入指示策略 | `never`/`instant`/`thinking`/`message` | 频道相关默认见文档 | `config set` |
| `agents.defaults.typingIntervalSeconds` | typing 间隔秒 | 正整数 | 未设置（文档示例 `6`） | `config set` |
| `agents.defaults.maxConcurrent` | 跨会话最大并行 Agent 数 | 正整数 | `4`（文档） | `config set` |

#### 2.1.2 工作区、引导与提示词

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.defaults.workspace` | 默认工作区目录 | 路径字符串 | 未设置 | `openclaw onboard` / `config set` |
| `agents.defaults.repoRoot` | 仓库根（若与 workspace 不同） | 路径 | 未设置 | `config set` |
| `agents.defaults.skills` | 技能 id 白名单 | 字符串数组；省略=不限制 | 未设置 | `config set` |
| `agents.defaults.skipBootstrap` | 跳过工作区引导注入 | `true`/`false` | 未设置 | `config set` |
| `agents.defaults.skipOptionalBootstrapFiles` | 跳过可选引导文件 | `SOUL.md` 等枚举数组 | 未设置 | `config set` |
| `agents.defaults.contextInjection` | 上下文注入策略 | `always`/`continuation-skip`/`never` | 未设置 | `config set` |
| `agents.defaults.bootstrapMaxChars` | 单文件引导最大字符 | 正整数 | `12000`（文档） | `config set` |
| `agents.defaults.bootstrapTotalMaxChars` | 引导总字符上限 | 正整数 | `60000`（文档） | `config set` |
| `agents.defaults.bootstrapPromptTruncationWarning` | 截断提示策略 | `off`/`once`/`always` | `once` | `config set` |
| `agents.defaults.userTimezone` | 系统提示中的时区 | IANA 字符串 | 主机时区 | `config set` |
| `agents.defaults.timeFormat` | 时间格式 | `auto`/`12`/`24` | `auto` | `config set` |
| `agents.defaults.envelopeTimezone` | 信封块时区 | 字符串 | 未设置 | `config set` |
| `agents.defaults.envelopeTimestamp` | 信封时间戳 | `on`/`off` | 未设置 | `config set` |
| `agents.defaults.envelopeElapsed` | 信封耗时 | `on`/`off` | 未设置 | `config set` |
| `agents.defaults.startupContext.enabled` | 是否在 new/reset 首回合注入启动上下文 | `true`/`false` | 未设置 | `config set` |
| `agents.defaults.startupContext.applyOn` | 应用时机 | `new`/`reset` 数组 | 未设置 | `config set` |
| `agents.defaults.startupContext.dailyMemoryDays` | 注入最近记忆天数 | 1–14 | 未设置 | `config set` |
| `agents.defaults.startupContext.maxFileBytes` | 单记忆文件最大字节 | 1–65536 | 未设置 | `config set` |
| `agents.defaults.startupContext.maxFileChars` | 单文件最大字符 | 1–10000 | 未设置 | `config set` |
| `agents.defaults.startupContext.maxTotalChars` | 启动上下文总字符 | 1–50000 | 未设置 | `config set` |
| `agents.defaults.systemPromptOverride` | 覆盖完整系统提示 | 字符串；空白=忽略 | 未设置 | `config set` |
| `agents.defaults.promptOverlays.gpt5.personality` | GPT5 人格覆盖 | `friendly`/`on`/`off` | 未设置 | `config set` |
| `agents.defaults.silentReply.direct` | 静默回复策略（私聊） | `allow`/`disallow` | 未设置 | `config set` |
| `agents.defaults.silentReply.group` | 群聊 | 同上 | 未设置 | `config set` |
| `agents.defaults.silentReply.internal` | 内部通道 | 同上 | 未设置 | `config set` |
| `agents.defaults.silentReplyRewrite.*` | 是否改写静默回复 | `boolean` 按通道 | 未设置 | `config set` |

#### 2.1.3 上下文限制、剪枝与压缩

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.defaults.contextLimits.memoryGetMaxChars` | `memory_get` 摘录上限 | 1–250000 | 未设置 | `config set` |
| `agents.defaults.contextLimits.memoryGetDefaultLines` | 默认行窗口 | 1–5000 | 未设置 | `config set` |
| `agents.defaults.contextLimits.toolResultMaxChars` | 工具结果最大字符 | 1–250000 | 未设置 | `config set` |
| `agents.defaults.contextLimits.postCompactionMaxChars` | 压缩后 AGENTS.md 摘录 | 1–50000 | 未设置 | `config set` |
| `agents.defaults.contextPruning.mode` | 会话内工具结果剪枝 | `off`/`cache-ttl` | 未设置 | `config set` |
| `agents.defaults.contextPruning.ttl` | 剪枝 TTL 字符串 | 时长字符串 | 未设置 | `config set` |
| `agents.defaults.contextPruning.keepLastAssistants` | 保留最近 assistant 条数 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.contextPruning.softTrimRatio` | 软裁剪比例 | 0–1 | 未设置 | `config set` |
| `agents.defaults.contextPruning.hardClearRatio` | 硬清理比例 | 0–1 | 未设置 | `config set` |
| `agents.defaults.contextPruning.minPrunableToolChars` | 可剪枝最小字符阈值 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.contextPruning.tools.allow` | 仅允许剪枝的工具 | 字符串数组 | 未设置 | `config set` |
| `agents.defaults.contextPruning.tools.deny` | 禁止剪枝的工具 | 字符串数组 | 未设置 | `config set` |
| `agents.defaults.contextPruning.softTrim.maxChars` 等 | 软裁剪窗口 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.contextPruning.hardClear.enabled` | 是否硬清理 | `boolean` | 未设置 | `config set` |
| `agents.defaults.contextPruning.hardClear.placeholder` | 替换占位文本 | 字符串 | 未设置 | `config set` |
| `agents.defaults.compaction.mode` | 压缩模式 | `default`/`safeguard` | 未设置 | `config set` |
| `agents.defaults.compaction.provider` | 压缩所用提供商 id | 字符串 | 未设置 | `config set` |
| `agents.defaults.compaction.reserveTokens` | 预留 token | 非负整数 | 未设置 | `config set` |
| `agents.defaults.compaction.keepRecentTokens` | 保留尾部 token | 正整数 | 未设置 | `config set` |
| `agents.defaults.compaction.reserveTokensFloor` | 预留下限 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.compaction.maxHistoryShare` | 历史占比上限 | 0.1–0.9 | 未设置 | `config set` |
| `agents.defaults.compaction.customInstructions` | 自定义压缩指令 | 字符串 | 未设置 | `config set` |
| `agents.defaults.compaction.identifierPolicy` | 标识策略 | `strict`/`off`/`custom` | 未设置 | `config set` |
| `agents.defaults.compaction.identifierInstructions` | 自定义标识说明 | 字符串 | 未设置 | `config set` |
| `agents.defaults.compaction.recentTurnsPreserve` | 保留最近轮数 | 0–12 | 未设置 | `config set` |
| `agents.defaults.compaction.qualityGuard.enabled` | 质量守护 | `boolean` | 未设置 | `config set` |
| `agents.defaults.compaction.qualityGuard.maxRetries` | 最大重试 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.compaction.midTurnPrecheck.enabled` | 回合内压力预检 | `boolean` | 未设置 | `config set` |
| `agents.defaults.compaction.postIndexSync` | 索引同步 | `off`/`async`/`await` | 未设置 | `config set` |
| `agents.defaults.compaction.postCompactionSections` | 压缩后刷新段落 | 字符串数组 | 未设置 | `config set` |
| `agents.defaults.compaction.model` | 压缩所用模型 ref | 字符串 | 未设置 | `config set` |
| `agents.defaults.compaction.timeoutSeconds` | 压缩超时 | 正整数 | 未设置 | `config set` |
| `agents.defaults.compaction.memoryFlush.*` | 内存刷盘策略 | 见 Schema | 未设置 | `config set` |
| `agents.defaults.compaction.truncateAfterCompaction` | 压缩后截断 | `boolean` | 未设置 | `config set` |
| `agents.defaults.compaction.maxActiveTranscriptBytes` | 活动 transcript 字节上限 | 字节大小字符串/数 | 未设置 | `config set` |
| `agents.defaults.compaction.notifyUser` | 是否通知用户压缩进度 | `boolean` | `false`（文档） | `config set` |

#### 2.1.4 记忆搜索、重试、子代理、沙箱、CLI 后端

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.defaults.memorySearch.enabled` | 启用记忆搜索 | `boolean` | 未设置 | `config set` |
| `agents.defaults.memorySearch.sources` | 搜索源 | `memory`/`sessions` | 未设置 | `config set` |
| `agents.defaults.memorySearch.extraPaths` | 额外路径 | 字符串数组 | 未设置 | `config set` |
| `agents.defaults.memorySearch.qmd.extraCollections[]` | QMD 额外集合 | `{path,name?,pattern?}` | 未设置 | 见 [memory-config](https://documentation.openclaw.ai/reference/memory-config) |
| `agents.defaults.memorySearch.multimodal.*` | 多模态索引 | 见 Schema | 未设置 | 同上 |
| `agents.defaults.memorySearch.experimental.sessionMemory` | 实验：会话记忆 | `boolean` | 未设置 | `config set` |
| `agents.defaults.memorySearch.provider` / `remote` / `fallback` / `model` 等 | 远程嵌入/批处理等 | 见 Schema | 未设置 | `config set` |
| `agents.defaults.memorySearch.chunking` / `sync` / `query` / `cache` / `store` / `local` | 索引分块、同步、检索、缓存、存储、本地模型 | 见 Schema | 未设置 | 同上 |
| `agents.defaults.runRetries.base` 等 | 运行重试策略 | 正整数/范围 | 未设置 | `config set` |
| `agents.defaults.embeddedPi.projectSettingsPolicy` | Pi 项目设置策略 | `trusted`/`sanitize`/`ignore` | 未设置 | `config set` |
| `agents.defaults.embeddedPi.executionContract` | 执行合约 | `default`/`strict-agentic` | 未设置 | `config set` |
| `agents.defaults.subagents.delegationMode` | 子代理委托 | `suggest`/`prefer` | 未设置 | `config set` |
| `agents.defaults.subagents.allowAgents` | 允许子代理 id | 字符串数组 | 未设置 | `config set` |
| `agents.defaults.subagents.maxConcurrent` | 子代理最大并发 | 正整数 | 未设置 | `config set` |
| `agents.defaults.subagents.maxSpawnDepth` | 最大嵌套深度 1–5 | 整数 | `1`（Schema 描述） | `config set` |
| `agents.defaults.subagents.maxChildrenPerAgent` | 单会话最大子代理数 1–20 | 整数 | `5`（Schema 描述） | `config set` |
| `agents.defaults.subagents.archiveAfterMinutes` | 归档空闲子代理 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.subagents.model` | 子代理默认模型 | 字符串或 `{primary,fallbacks}` | 未设置 | `config set` |
| `agents.defaults.subagents.thinking` | 子代理 thinking 覆盖 | 字符串 | 未设置 | `config set` |
| `agents.defaults.subagents.runTimeoutSeconds` | 子代理运行超时 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.subagents.announceTimeoutMs` | 宣告超时 | 正整数 | 未设置 | `config set` |
| `agents.defaults.subagents.requireAgentId` | 强制显式 agentId | `boolean` | `false` | `config set` |
| `agents.defaults.sandbox.mode` | 沙箱模式 | `off`/`non-main`/`all` | 未设置 | `config set` |
| `agents.defaults.sandbox.backend` | 后端 | `docker`/`ssh`/插件名 | 未设置 | `config set` |
| `agents.defaults.sandbox.workspaceAccess` | 工作区挂载 | `none`/`ro`/`rw` | 未设置 | `config set` |
| `agents.defaults.sandbox.sessionToolsVisibility` | 会话工具可见性 | `spawned`/`all` | 未设置 | `config set` |
| `agents.defaults.sandbox.scope` | 沙箱作用域 | `session`/`agent`/`shared` | 未设置 | `config set` |
| `agents.defaults.sandbox.workspaceRoot` | 沙箱根目录 | 路径 | 未设置 | `config set` |
| `agents.defaults.sandbox.docker.*` | Docker 资源、网络、绑定等 | 见 [Sandboxing](https://docs.openclaw.ai/gateway/sandboxing) | 未设置 | `config set` |
| `agents.defaults.sandbox.ssh.*` | SSH 后端 | 目标/密钥等 | 未设置 | `config set` |
| `agents.defaults.sandbox.browser.*` | 沙箱浏览器 sidecar | 端口/VNC 等 | 未设置 | `config set` |
| `agents.defaults.sandbox.prune.*` | 容器回收策略 | `idleHours`/`maxAgeDays` | 未设置 | `config set` |
| `agents.defaults.cliBackends.<name>` | 无工具 CLI 回退后端 | `CliBackendSchema` | 未设置 | `config set` |
| `agents.defaults.agentRuntime` | **废弃**：整 Agent 运行时 | `{id?}` | **忽略** | `openclaw doctor --fix` |
| `agents.defaults.embeddedHarness` | 嵌入式 harness | `{runtime?}` | 未设置 | `config set` |
| `agents.defaults.experimental.localModelLean` | 实验：本地模型精简 | `boolean` | 未设置 | `config set` |

#### 2.1.5 心跳

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.defaults.heartbeat.every` | 周期间隔 | `ms/s/m/h` 时长字符串 | 未设置 | `openclaw config set agents.defaults.heartbeat.every "2h"` |
| `agents.defaults.heartbeat.activeHours` | 允许运行的小时窗口 | `{start,end,timezone}` `HH:MM` | 未设置 | `config set` |
| `agents.defaults.heartbeat.model` | 心跳所用模型 ref | 字符串 | 未设置 | `config set` |
| `agents.defaults.heartbeat.session` | 心跳会话目标 | 字符串 | 未设置 | `config set` |
| `agents.defaults.heartbeat.includeReasoning` | 是否包含推理 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.target` / `to` / `accountId` | 投递目标（通道相关） | 字符串 | 未设置 | `config set` |
| `agents.defaults.heartbeat.prompt` | 心跳提示词 | 字符串 | 未设置 | `config set` |
| `agents.defaults.heartbeat.includeSystemPromptSection` | 是否包含 Heartbeat 系统段 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.ackMaxChars` | ack 最大字符 | 非负整数 | 未设置 | `config set` |
| `agents.defaults.heartbeat.suppressToolErrorWarnings` | 抑制工具错误警告 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.timeoutSeconds` | 心跳回合超时；未设置继承 `timeoutSeconds` | 正整数 | 未设置 | `config set` |
| `agents.defaults.heartbeat.lightContext` | 轻量上下文 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.isolatedSession` | 独立会话 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.skipWhenBusy` | 忙时跳过 | `boolean` | 未设置 | `config set` |
| `agents.defaults.heartbeat.directPolicy` | 私聊策略 | `allow`/`block` | 未设置 | `config set` |

### 2.2 `agents.list[]`（多代理项）

除下列 **专有** 字段外，其余与 `agents.defaults` 同名键含义相同且 **覆盖默认值**（见 Zod `AgentEntrySchema`）。

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `agents.list[].id` | 稳定 Agent id | 非空字符串 | **必填** | `openclaw agent`（创建/维护目录时）/ `config set` |
| `agents.list[].default` | 是否为默认 Agent | `true`/`false` | 未设置（首条兜底） | `config set` |
| `agents.list[].name` | 显示名 | 字符串 | 未设置 | `config set` |
| `agents.list[].workspace` | 工作区路径 | 路径 | 继承 | `config set` |
| `agents.list[].agentDir` | Agent 状态目录 | 路径 | 继承 | `openclaw agent` |
| `agents.list[].fastModeDefault` | 每 Agent 默认 fast 模式 | `boolean` | 未设置 | `config set` |
| `agents.list[].identity.name` 等 | 人格/头像 | 见 `IdentitySchema` | 未设置 | `config set` |
| `agents.list[].groupChat` | 群聊提及/历史限制等 | `GroupChatSchema` | 未设置 | `config set` |
| `agents.list[].tts` | TTS 覆盖（与 `messages.tts` 深度合并） | `TtsConfigSchema` | 未设置 | 见 TTS 文档 |
| `agents.list[].skillsLimits.maxSkillsPromptChars` | 技能列表字符上限 | 非负整数 | 继承 `skills.limits` | `config set` |
| `agents.list[].runtime` | 每 Agent 运行时描述 | `embedded` / `acp`+`acp`对象 | 未设置 | `config set` |
| `agents.list[].tools` | 每 Agent 工具策略 | `AgentToolsSchema` | 未设置 | `config set` |

**与 defaults 同形字段（覆盖）**：`model`、`models`、`thinkingDefault`、`verboseDefault`、`toolProgressDetail`、`reasoningDefault`、`skills`、`memorySearch`、`humanDelay`、`contextLimits`、`contextTokens`、`heartbeat`、`runRetries`、`embeddedPi`、`sandbox`、`params`、`systemPromptOverride`、`agentRuntime`、`embeddedHarness` 等。

### 2.3 根级 `bindings[]`（多代理路由）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `bindings[].type` | 绑定类型 | `route`（省略同 route）/`acp` | 未设置 | `config set` |
| `bindings[].agentId` | 目标 Agent | 字符串 | **必填** | `config set` |
| `bindings[].comment` | 备注 | 字符串 | 未设置 | 无 |
| `bindings[].match.channel` | 通道 id | 字符串 | **必填** | `config set` |
| `bindings[].match.accountId` | 账户 id | 字符串 | 未设置 | `config set` |
| `bindings[].match.peer.kind` | 会话类型 | `direct`/`group`/`channel`/`dm`(弃用) | 未设置 | `config set` |
| `bindings[].match.peer.id` | 会话/用户 id | 字符串 | 视类型必填 | `config set` |
| `bindings[].match.guildId` / `teamId` / `roles` | 平台特定匹配 | 字符串/数组 | 未设置 | `config set` |
| `bindings[].session` | 会话策略覆盖 | `dmScope` 等 | 未设置 | `config set` |
| `bindings[].acp`（`type=acp`） | ACP 绑定细节 | `mode`/`label`/`cwd`/`backend` | 未设置 | `config set` |

### 2.4 根级 `broadcast`

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `broadcast.strategy` | 广播策略 | `parallel`/`sequential` | 未设置 | `config set` |
| `broadcast.<peerId>` | 每 peer 的 agent id 列表 | 字符串数组 | 未设置 | `config set` |

### 2.5 根级 `session`

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `session.scope` | 会话分组 | `per-sender`/`global` | 未设置 | `config set` |
| `session.dmScope` | DM 会话范围 | `main`/`per-peer`/… | 未设置 | `config set` |
| `session.identityLinks` | 身份链接映射 | `Record<string,string[]>` | 未设置 | `config set` |
| `session.resetTriggers` | 触发重置的标记数组 | 字符串数组 | 未设置 | `config set` |
| `session.idleMinutes` | 空闲分钟 | 正整数 | 未设置 | `config set` |
| `session.reset` / `resetByType` / `resetByChannel` | 定时/分类重置 | 见 Schema | 未设置 | `config set` |
| `session.store` | 会话存储路径/后端 | 字符串 | 未设置 | `config set` |
| `session.typingIntervalSeconds` | 会话级 typing 间隔 | 正整数 | 未设置 | `config set` |
| `session.typingMode` | 会话级 typing 模式 | `TypingModeSchema` | 未设置 | `config set` |
| `session.mainKey` | 主会话键策略 | 字符串 | 未设置 | `config set` |
| `session.sendPolicy` | 发送策略（allow/deny 规则） | 复杂对象 | 未设置 | `config set` |
| `session.writeLock.acquireTimeoutMs` | 写锁获取超时 | 正整数 | 未设置 | `config set` |
| `session.agentToAgent.maxPingPongTurns` | Agent 互 ping 最大轮数 | 0–20 | 未设置 | `config set` |
| `session.threadBindings.*` | 线程绑定与 spawn | 见 Schema | 未设置 | `config set` |
| `session.maintenance.*` | 会话维护/裁剪 | `mode`/`pruneAfter`/`maxEntries`/… | `maxEntries` 默认 `500`（文档） | `openclaw sessions cleanup --enforce` |

### 2.6 根级 `messages` 与 `talk`

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `messages.messagePrefix` | 消息前缀 | 字符串 | 未设置 | `config set` |
| `messages.visibleReplies` | 可见回复策略 | `automatic`/`message_tool`/布尔 | 未设置 | `config set` |
| `messages.responsePrefix` | 响应前缀 | 字符串 | 未设置 | `config set` |
| `messages.groupChat` | 群聊覆盖 | `GroupChatSchema` | 未设置 | `config set` |
| `messages.queue` | 队列模式/丢弃策略等 | `QueueSchema` | 未设置 | `config set` |
| `messages.inbound` | 入站防抖等 | `InboundDebounceSchema` | 未设置 | `config set` |
| `messages.ackReaction` / `ackReactionScope` / `removeAckAfterReply` | Ack 反应行为 | 枚举/布尔 | 未设置 | `config set` |
| `messages.statusReactions.*` | 状态表情与时间 | 嵌套对象 | 未设置 | `config set` |
| `messages.suppressToolErrors` | 抑制工具错误展示 | `boolean` | 未设置 | `config set` |
| `messages.tts` | 全局 TTS 配置 | `TtsConfigSchema` | 未设置 | 见 TTS 文档 |
| `talk.provider` / `talk.providers` | Talk 提供商选择与映射 | 字符串 / 对象 | 未设置 | `config set` |
| `talk.realtime` | 实时 Talk 子配置 | 对象 | 未设置 | `config set` |
| `talk.consultThinkingLevel` | Control UI 咨询 thinking | 同 thinking 枚举 | 未设置 | `config set` |
| `talk.consultFastMode` | 咨询 fast 模式 | `boolean` | 未设置 | `config set` |
| `talk.speechLocale` | 语音识别区域 | BCP47 | 未设置 | `config set` |
| `talk.interruptOnSpeech` | 语音打断 | `boolean` | 未设置 | `config set` |
| `talk.silenceTimeoutMs` | 静音超时 | 正整数 | 平台默认 | `config set` |

### 2.7 根级 `skills.*`（与 Agent 技能加载/提示相关）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `skills.allowBundled` | 允许加载的内置技能 id | 字符串数组 | 未设置 | `config set` |
| `skills.load.extraDirs` | 额外技能根目录 | 路径数组 | 未设置 | `config set` |
| `skills.load.allowSymlinkTargets` | 允许符号链接目标 | 路径数组 | 未设置 | `config set` |
| `skills.load.watch` / `watchDebounceMs` | 监视技能目录变更 | `boolean` / 毫秒 | 未设置 | `config set` |
| `skills.install.preferBrew` 等 | 技能安装偏好 | 见 Schema | 未设置 | `config set` |
| `skills.limits.maxCandidatesPerRoot` | 每根目录候选技能上限 | 正整数 | 未设置 | `config set` |
| `skills.limits.maxSkillsLoadedPerSource` | 每源最大加载技能数 | 正整数 | 未设置 | `config set` |
| `skills.limits.maxSkillsInPrompt` | 注入提示的技能条目数上限 | 非负整数 | 未设置 | `config set` |
| `skills.limits.maxSkillsPromptChars` | 技能列表提示最大字符 | 非负整数 | 未设置 | `config set` |
| `skills.limits.maxSkillFileBytes` | 单个 SKILL.md 最大字节 | 非负整数 | 未设置 | `config set` |
| `skills.entries` | 自定义技能条目映射 | `Record<string, SkillEntry>` | 未设置 | `config set` |

### 2.8 根级 `tools`（工具策略，非 `agents` 子树）

| 参数 | 作用 | 可选值 | 默认值 | CLI |
|------|------|--------|--------|-----|
| `tools` | 全局工具白名单/黑名单、`web`/`exec`/… | 超大嵌套对象 | 未设置 | `openclaw config set tools… --strict-json --merge`；细则见 [config-tools](https://documentation.openclaw.ai/gateway/config-tools) |

> 未展开 `tools.*` 全叶子键；完整表请使用 `openclaw config schema` 或阅读 `zod-schema.agent-runtime.ts` 中 `ToolsSchema` 与相关子 schema。

### 2.9 Agent 完整示例（JSON5 + 注释）

```json5
{
  agents: {
    defaults: {
      workspace: "~/.openclaw/workspace",
      model: {
        primary: "anthropic/claude-sonnet-4-6",
        fallbacks: ["openai/gpt-5.4-mini"],
      },
      models: {
        "anthropic/claude-sonnet-4-6": { alias: "sonnet", params: { temperature: 0.2 } },
        "openai/gpt-5.4-mini": { alias: "mini" },
      },
      params: { cacheRetention: "long" }, // 全局默认，按 key 被 per-model/per-agent 覆盖
      contextTokens: 200000,
      thinkingDefault: "low",
      sandbox: { mode: "off" },
      heartbeat: { every: "4h", lightContext: false },
    },
    list: [
      {
        id: "main",
        default: true,
        name: "Main",
        workspace: "~/.openclaw/workspace",
        agentDir: "~/.openclaw/agents/main/agent",
        model: { primary: "anthropic/claude-sonnet-4-6", fallbacks: [] }, // 显式 fallbacks: [] = 严格无回退
        params: { cacheRetention: "none" }, // 仅覆盖该 Agent 的默认流参数键
        skills: [], // 空数组 = 禁用技能（与省略 defaults.skills 不同）
        sandbox: { mode: "non-main", backend: "docker" },
      },
    ],
  },
  bindings: [
    // 将 WhatsApp personal 账号流量路由到 main Agent
    { agentId: "main", match: { channel: "whatsapp", accountId: "personal" } },
  ],
  session: {
    scope: "per-sender",
    maintenance: { maxEntries: 500 },
  },
  messages: {
    visibleReplies: "automatic",
  },
}
```

### 2.10 Agent 侧：CLI 速查

| 命令 | 用途 |
|------|------|
| `openclaw onboard` | 引导配置模型与鉴权 |
| `openclaw configure --section model` | 交互配置模型相关片段 |
| `openclaw config get <path> [--json]` | 读取任意配置路径 |
| `openclaw config set <path> <value> [--strict-json] [--merge\|--replace]` | 写入；模型映射务必 `--merge` |
| `openclaw config validate` | 校验配置 |
| `openclaw config schema` | 打印合并后 JSON Schema |
| `openclaw doctor --fix` | 迁移/清理废弃键（含弃用 agentRuntime 根字段） |
| `openclaw agent` | 维护 per-agent 目录与 `models.json`（见 CLI 帮助） |
| `openclaw sessions cleanup --enforce` | 立即执行会话条数上限维护 |

---

## 参考链接

| 标题 | URL |
|------|-----|
| Configuration reference | https://documentation.openclaw.ai/gateway/configuration-reference |
| Configuration - agents | https://documentation.openclaw.ai/gateway/config-agents |
| Configuration - tools and custom providers | https://documentation.openclaw.ai/gateway/config-tools |
| Models CLI | https://docs.openclaw.ai/cli/models |
| Config CLI | https://docs.openclaw.ai/cli/config |
| Model providers（上下文窗口与 `models.providers` 语义） | https://docs.openclaw.ai/concepts/model-providers |
| Models 概念与 `/model` | https://docs.openclaw.ai/concepts/models |
| Sandboxing | https://docs.openclaw.ai/gateway/sandboxing |
| Memory configuration reference | https://documentation.openclaw.ai/reference/memory-config |
| Zod：`ModelsConfigSchema` / `ModelProviderSchema` | https://github.com/openclaw/openclaw/blob/main/src/config/zod-schema.core.ts |
| Zod：`AgentDefaultsSchema` | https://github.com/openclaw/openclaw/blob/main/src/config/zod-schema.agent-defaults.ts |
| Zod：`AgentEntrySchema` / `MemorySearchSchema` / `AgentSandboxSchema` | https://github.com/openclaw/openclaw/blob/main/src/config/zod-schema.agent-runtime.ts |
| Zod：`AgentsSchema` / `bindings` | https://github.com/openclaw/openclaw/blob/main/src/config/zod-schema.agents.ts |
| Zod：`SessionSchema` / `MessagesSchema` | https://github.com/openclaw/openclaw/blob/main/src/config/zod-schema.session.ts |
| Model API 枚举 | https://github.com/openclaw/openclaw/blob/main/src/config/types.models.ts |
