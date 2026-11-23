<div align="center">

<img src="assets/logo.png" alt="Antigravity File Opener Logo" width="128" />

<h1>Antigravity File Opener</h1>

<p>
  为 <strong>macOS &amp; Windows</strong> 版 <strong>Antigravity 2.0</strong> 对话区文件胶囊提供系统原生右键菜单与快捷默认应用打开增强<br />
  不修改客户端本体 · 无需管理员/辅助功能权限 · 兼容 <code>theme-patch</code> 与 <code>context-viewer</code>
</p>

<p>
  <strong>简体中文</strong> &nbsp;|&nbsp; <a href="README.en.md">English</a>
</p>

<p>
  <img src="https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white" alt="macOS 13+" />
  <img src="https://img.shields.io/badge/Windows-10%20%2F%2011-0078D6?style=flat&logo=windows&logoColor=white" alt="Windows 10/11" />
  <img src="https://img.shields.io/badge/Target-Antigravity%202.0-1A73E8?style=flat&logo=google&logoColor=white" alt="Antigravity 2.0" />
  <img src="https://img.shields.io/badge/Menu-Native%20NSMenu%20%2F%20Win32-0A84FF?style=flat" alt="Native Menu" />
  <img src="https://img.shields.io/badge/Permissions-Zero%20Admin%20%2F%20Accessibility-10B981?style=flat" alt="Zero Permissions" />
  <a href="https://github.com/JaffryGao/antigravity-file-opener/actions/workflows/ci.yml">
    <img src="https://github.com/JaffryGao/antigravity-file-opener/actions/workflows/ci.yml/badge.svg" alt="CI Status" />
  </a>
</p>

<p>
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat&logo=swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/C%23-.NET%20Win32%20(Zero%20SDK)-512BD4?style=flat&logo=dotnet&logoColor=white" alt="C# Win32" />
  <img src="https://img.shields.io/badge/AppKit-NSWorkspace%20%26%20NSMenu-0071E3?style=flat" alt="AppKit" />
  <img src="https://img.shields.io/badge/IPC-Loopback%20127.0.0.1-4F46E5?style=flat" alt="Loopback 127.0.0.1" />
  <img src="https://img.shields.io/badge/JavaScript-DOM%20Capture-F7DF1E?style=flat&logo=javascript&logoColor=000000" alt="JavaScript" />
  <img src="https://img.shields.io/badge/Node.js-Sync%20CLI-339933?style=flat&logo=nodedotjs&logoColor=white" alt="Node.js" />
</p>

<br />

<img src="assets/preview.png" alt="Antigravity File Opener 原生液态玻璃右键菜单预览" width="760" />

</div>

---

## 一键安装 Prompt（点右上角复制，发给 AI 助手自动装，自动识别 macOS / Windows）

点击下面代码块右上角的 **复制按钮**，直接粘贴给 **Antigravity / Claude Code / Codex**，AI 会自动识别你的操作系统并完成检查、克隆、编译、安装与验证：

```text
请帮我安装并启用 https://github.com/JaffryGao/antigravity-file-opener （Antigravity 文件胶囊系统原生右键菜单与快捷默认应用打开增强，支持 macOS 和 Windows）：

1. 先识别当前操作系统（macOS 或 Windows）并检查前置环境：
   - 通用要求：`node` 可用，且 `~/.gemini/antigravity/theme-patch/user/custom.js`（Windows 为 `%USERPROFILE%\.gemini\antigravity\theme-patch\user\custom.js`）存在且 `theme-patch/user/config.json` 中 `"customJs": true`。
   - macOS 额外要求：macOS 13+、`swiftc`（Xcode Command Line Tools）可用。
   - Windows 额外要求：Windows 10/11（使用系统自带 `.NET Framework csc.exe`，无需额外安装 SDK）。
   若有缺失请先告诉我如何补齐再继续。
2. 克隆仓库到用户目录 `~/antigravity-file-opener`（Windows 为 `%USERPROFILE%\antigravity-file-opener`，已存在则先拉取最新代码）：
   git clone https://github.com/JaffryGao/antigravity-file-opener.git ~/antigravity-file-opener
3. 按系统执行一键构建、安装与开机自启：
   - macOS：
     cd ~/antigravity-file-opener && chmod +x build.sh install-service.sh uninstall.sh && ./install-service.sh
   - Windows (PowerShell)：
     cd "$env:USERPROFILE\antigravity-file-opener"; powershell -ExecutionPolicy Bypass -File .\windows\install-service.ps1
4. 执行安装后验证：
   - 确认单元测试与构建全部通过；
   - 访问 `http://127.0.0.1:59321/health` 确认返回 `{"ok":true,"service":"AntigravityFileOpener"}`；
   - 确认 `theme-patch/user/custom.js` 语法检查通过并已热重载。
5. 完成后告诉我测试方式（macOS 为 `⌘ + 左键单击` / `右键单击`；Windows 为 `Ctrl + 左键单击` / `右键单击`）以及对应的卸载脚本路径。
```

### 手动一键安装

- **macOS（Terminal）**：
  ```zsh
  git clone https://github.com/JaffryGao/antigravity-file-opener.git ~/antigravity-file-opener
  cd ~/antigravity-file-opener
  chmod +x build.sh install-service.sh uninstall.sh
  ./install-service.sh
  ```

- **Windows 10 / 11（PowerShell，无需管理员权限、无需安装 .NET SDK）**：
  ```powershell
  git clone https://github.com/JaffryGao/antigravity-file-opener.git "$env:USERPROFILE\antigravity-file-opener"
  cd "$env:USERPROFILE\antigravity-file-opener"
  powershell -ExecutionPolicy Bypass -File .\windows\install-service.ps1
  ```

> 两个平台均**无需重启 Antigravity**、**无需管理员或辅助功能权限**，约 1~2 秒自动热生效；重启 Antigravity 或重启电脑后均会自动静默可用。

---

## 核心功能（macOS & Windows 对齐）

| 交互操作 | macOS 效果 | Windows 10 / 11 效果 |
| :--- | :--- | :--- |
| **快捷默认应用打开** | **`⌘ + 左键单击`** 文件/目录胶囊：拦截内部打开，用 macOS 默认应用打开 | **`Ctrl + 左键单击`** 文件/目录胶囊：拦截内部打开，调用 `ShellExecute` 用 Windows 默认应用打开 |
| **系统原生右键菜单** | **`右键单击`**：弹出真·AppKit **`NSMenu`**（Finder 同款 Liquid Glass 液态玻璃质感） | **`右键单击`**：弹出 Win32/WinForms 原生菜单（Win11 DWM 圆角 + 自动跟随系统深浅色） |
| **打开方式** | **打开方式 ›** 子菜单，自动列出本机所有可打开该文件的应用及真实图标 | **打开方式…**，直接唤起 Windows 原生 `OpenAs_RunDLL` 应用选择窗口 |
| **打开所在文件夹** | **在 Finder 中显示**（高亮选中文件） | **在文件资源管理器中显示**（优先 `SHOpenFolderAndSelectItems` 复用窗口高亮选中） |
| **复制路径与文件名** | **复制完整路径** / **复制文件名**（自动恢复原窗口焦点） | **复制完整路径** / **复制文件名**（支持 `C:\...` 与 `\\wsl.localhost\...`） |
| **临时逃生通道** | **`⌥ + 右键单击`** 放行 Antigravity 原生右键菜单 | **`Alt + 右键单击`** 放行 Antigravity 原生右键菜单 |

---

## 工作原理与架构

采用 **「统一跨平台前端 DOM 捕获 + 原生后台回环执行器」** 两段式解耦架构：

```text
Antigravity 渲染层 (~/.gemini/antigravity/theme-patch/user/custom.js)
  ├─ macOS: ⌘+单击 / Windows: Ctrl+单击 ──▶ POST http://127.0.0.1:59321/open
  └─ 右键单击 .inline-pill[data-uri]    ──▶ POST http://127.0.0.1:59321/menu
                                                      │
                     ┌────────────────────────────────┴────────────────────────────────┐
                     ▼                                                                 ▼
  macOS 后台服务 (Swift / LaunchAgent)                       Windows 后台服务 (C# Win32 / HKCU Run)
  ├─ /Applications/AntigravityFileOpener.app                 ├─ %LOCALAPPDATA%\AntigravityFileOpener\...exe
  ├─ POSIX 127.0.0.1:59321 + 0600 随机 Token                 ├─ TcpListener 127.0.0.1:59321 + 随机 Token
  ├─ AppKit 原生 NSMenu + 打开方式 › 子菜单                  ├─ Win11 圆角深浅色菜单 + OpenAs_RunDLL
  └─ NSWorkspace.open / activateFileViewerSelecting          └─ ShellExecute / SHOpenFolderAndSelectItems
```

---

## 目录结构

```text
antigravity-file-opener/
├── README.md / README.en.md         # 中英双语文档
├── .github/workflows/ci.yml         # macOS + Windows 双平台自动构建与端到端冒烟验证
├── assets/
│   ├── logo.png                     # 项目 Logo
│   └── preview.png                  # macOS 原生液态玻璃右键菜单预览
├── frontend/
│   └── file-opener-snippet.js       # macOS + Windows 通用前端拦截模块（支持 POSIX / 盘符 / WSL UNC）
├── sync-custom-js.mjs               # 跨平台同步脚本（自动定位用户目录注入/清理 custom.js）
├── Sources/                         # macOS 原生 Swift 源码
├── Tests/
│   ├── FileLinkParserTests.swift    # macOS 路径解析单元测试 (17 项)
│   └── frontend-path.test.mjs       # 前端跨平台路径解析单元测试 (13 项)
├── build.sh / install-service.sh / uninstall.sh
└── windows/                         # Windows 原生 C# 源码与一键脚本（基于系统内置 csc.exe，零 SDK 依赖）
    ├── FileLinkParser.cs            # Windows 盘符与 WSL UNC 路径解析器
    ├── LocalActionServer.cs         # TcpListener 127.0.0.1 回环服务（免管理员 URLACL）
    ├── ContextMenuPresenter.cs      # Win11 圆角深浅色右键菜单 + Win32 Shell 打开/定位
    ├── Program.cs                   # 单实例 Mutex + 随机 Token + 静默无黑框入口
    ├── FileLinkParserTests.cs       # Windows 单元测试 (15 项)
    └── build.ps1 / install-service.ps1 / uninstall.ps1
```

---

## 安全设计

- **不改动 `Antigravity.app` / `Antigravity.exe` 本体**：不拆包 `app.asar`，官方更新不会覆盖。
- **仅本机回环监听**：仅绑定 `127.0.0.1:59321`，局域网与外网完全不可访问，不触发 Windows 防火墙公网告警。
- **独立随机 Token + Origin 白名单**：首次启动自动生成 32 字节随机密钥保存于 `~/.config/antigravity-file-opener/token`，拒绝无 Token（`401`）与公网来源请求（`403`）。
- **零 Shell 注入**：仅校验目标文件/目录存在后调用系统原生 API，不拼接外部命令行。

---

## 排障检查与一键卸载

### macOS
```zsh
# 检查服务状态与健康接口
launchctl print "gui/$(id -u)/com.antigravity.file-opener" | grep -E "state =|pid ="
curl -sS http://127.0.0.1:59321/health
cat /tmp/antigravity-file-opener.log

# 一键彻底卸载
~/antigravity-file-opener/uninstall.sh
```

### Windows (PowerShell)
```powershell
# 检查进程、健康接口与日志
Get-Process AntigravityFileOpener -ErrorAction SilentlyContinue
Invoke-RestMethod http://127.0.0.1:59321/health
Get-Content "$env:TEMP\antigravity-file-opener.log" -Tail 20

# 一键彻底卸载
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\antigravity-file-opener\windows\uninstall.ps1"
```
