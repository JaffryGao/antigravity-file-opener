<div align="center">

<img src="assets/logo.png" alt="Antigravity File Opener Logo" width="128" />

<h1>Antigravity File Opener</h1>

<p>
  Native system context menu &amp; quick external file opener for <strong>Antigravity 2.0</strong> chat file pills on <strong>macOS &amp; Windows</strong><br />
  Zero client binary patching · No admin or Accessibility permissions · Compatible with <code>theme-patch</code> &amp; <code>context-viewer</code>
</p>

<p>
  <a href="README.md">简体中文</a> &nbsp;|&nbsp; <strong>English</strong>
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

<img src="assets/preview.png" alt="Antigravity File Opener Native Liquid Glass Context Menu Preview" width="760" />

</div>

---

## One-Click AI Install Prompt (macOS & Windows Auto-Detect)

Click the **Copy** button in the top-right corner below and paste it into **Antigravity / Claude Code / Codex** to automatically detect your OS, check prerequisites, build, install, and verify:

```text
Please install and enable https://github.com/JaffryGao/antigravity-file-opener (native OS context menu and quick external file opening for Antigravity chat file pills on macOS and Windows):

1. Detect the current OS (macOS or Windows) and check prerequisites:
   - Common: `node` is available, and `~/.gemini/antigravity/theme-patch/user/custom.js` (Windows: `%USERPROFILE%\.gemini\antigravity\theme-patch\user\custom.js`) exists with `"customJs": true` in `theme-patch/user/config.json`.
   - macOS: macOS 13+ and `swiftc` (Xcode Command Line Tools).
   - Windows: Windows 10/11 (uses built-in `.NET Framework csc.exe`, no extra SDK required).
   If anything is missing, explain how to install/enable it before proceeding.
2. Clone the repo to `~/antigravity-file-opener` (Windows: `%USERPROFILE%\antigravity-file-opener`, or pull latest if already cloned):
   git clone https://github.com/JaffryGao/antigravity-file-opener.git ~/antigravity-file-opener
3. Run the platform installer:
   - macOS:
     cd ~/antigravity-file-opener && chmod +x build.sh install-service.sh uninstall.sh && ./install-service.sh
   - Windows (PowerShell):
     cd "$env:USERPROFILE\antigravity-file-opener"; powershell -ExecutionPolicy Bypass -File .\windows\install-service.ps1
4. Verify the installation:
   - Confirm unit tests and build passed;
   - Verify `http://127.0.0.1:59321/health` returns `{"ok":true,"service":"AntigravityFileOpener"}`;
   - Confirm `theme-patch/user/custom.js` passes syntax checks and hot-reloaded.
5. Tell me how to test (`⌘ + Click` / `Right-Click` on macOS, `Ctrl + Click` / `Right-Click` on Windows) and the uninstall script path.
```

### Manual Quick Install

- **macOS (Terminal)**:
  ```zsh
  git clone https://github.com/JaffryGao/antigravity-file-opener.git ~/antigravity-file-opener
  cd ~/antigravity-file-opener
  chmod +x build.sh install-service.sh uninstall.sh
  ./install-service.sh
  ```

- **Windows 10 / 11 (PowerShell — No Admin Rights, No .NET SDK Needed)**:
  ```powershell
  git clone https://github.com/JaffryGao/antigravity-file-opener.git "$env:USERPROFILE\antigravity-file-opener"
  cd "$env:USERPROFILE\antigravity-file-opener"
  powershell -ExecutionPolicy Bypass -File .\windows\install-service.ps1
  ```

> **No Antigravity restart**, **no admin privileges**, and **no Accessibility permission prompts** required. Hot-reloads in ~1–2 seconds and persists across app restarts and system reboots.

---

## Feature Parity (macOS & Windows)

| Action | macOS | Windows 10 / 11 |
| :--- | :--- | :--- |
| **Quick Default App Open** | **`⌘ + Left-Click`** on file/folder pill → opens in macOS default app via `NSWorkspace` | **`Ctrl + Left-Click`** on file/folder pill → opens in Windows default app via `ShellExecute` |
| **Native Context Menu** | **`Right-Click`** → genuine AppKit **`NSMenu`** (Finder Liquid Glass style) | **`Right-Click`** → native Win32/WinForms menu (Win11 DWM rounded corners + auto dark/light theme) |
| **Open With** | **Open With ›** submenu listing all registered apps with real icons | **Open With…** invoking native Windows `OpenAs_RunDLL` app chooser |
| **Reveal Folder** | **Reveal in Finder** (highlights target) | **Show in File Explorer** (`SHOpenFolderAndSelectItems` with fallback to `explorer /select`) |
| **Copy Path / Filename** | **Copy Full Path** / **Copy Filename** (restores focus) | **Copy Full Path** / **Copy Filename** (supports drive letters & `\\wsl.localhost\...` UNC paths) |
| **Escape Hatch** | **`⌥ + Right-Click`** passes through to Antigravity's original menu | **`Alt + Right-Click`** passes through to Antigravity's original menu |

---

## Architecture

A decoupled cross-platform design pairing **capture-phase DOM interception** with a **platform-native loopback executor**:

```text
Antigravity Renderer (~/.gemini/antigravity/theme-patch/user/custom.js)
  ├─ macOS: ⌘+Click / Windows: Ctrl+Click ──▶ POST http://127.0.0.1:59321/open
  └─ Right-Click .inline-pill[data-uri]   ──▶ POST http://127.0.0.1:59321/menu
                                                      │
                     ┌────────────────────────────────┴────────────────────────────────┐
                     ▼                                                                 ▼
  macOS Daemon (Swift / LaunchAgent)                         Windows Daemon (C# Win32 / HKCU Run)
  ├─ /Applications/AntigravityFileOpener.app                 ├─ %LOCALAPPDATA%\AntigravityFileOpener\...exe
  ├─ POSIX 127.0.0.1:59321 + 0600 random token               ├─ TcpListener 127.0.0.1:59321 + random token
  ├─ AppKit NSMenu + Open With › submenu                     ├─ Win11 rounded dark/light menu + OpenAs_RunDLL
  └─ NSWorkspace.open / activateFileViewerSelecting          └─ ShellExecute / SHOpenFolderAndSelectItems
```

---

## Project Structure

```text
antigravity-file-opener/
├── README.md / README.en.md         # Bilingual documentation
├── .github/workflows/ci.yml         # macOS + Windows CI build & end-to-end loopback smoke tests
├── assets/
│   ├── logo.png                     # Custom Liquid Glass project logo
│   └── preview.png                  # Native macOS context menu screenshot
├── frontend/
│   └── file-opener-snippet.js       # Cross-platform DOM listener (POSIX, Windows drives & WSL UNC)
├── sync-custom-js.mjs               # Cross-platform injector/cleaner for theme-patch/user/custom.js
├── Sources/                         # macOS native Swift sources
├── Tests/
│   ├── FileLinkParserTests.swift    # macOS unit tests (17 assertions)
│   └── frontend-path.test.mjs       # Cross-platform frontend path tests (13 assertions)
├── build.sh / install-service.sh / uninstall.sh
└── windows/                         # Windows native C# sources (compiled with built-in csc.exe, zero SDK)
    ├── FileLinkParser.cs            # Drive letter & WSL UNC path resolver
    ├── LocalActionServer.cs         # Loopback-only TcpListener server (no admin URLACL needed)
    ├── ContextMenuPresenter.cs      # Win11 rounded theme-aware menu + Win32 Shell APIs
    ├── Program.cs                   # Single-instance Mutex + random token + silent entrypoint
    ├── FileLinkParserTests.cs       # Windows unit tests (15 assertions)
    └── build.ps1 / install-service.ps1 / uninstall.ps1
```

---

## Security

- **Untouched Host App**: Never modifies `Antigravity.app` / `Antigravity.exe` or `app.asar`; survives official updates.
- **Loopback-Only Binding**: Strictly binds to `127.0.0.1:59321` (unreachable from LAN/internet; avoids Windows Firewall public prompts).
- **Random Token + Origin Allowlist**: Generates a 32-byte per-machine token at `~/.config/antigravity-file-opener/token`, rejecting unauthorized (`401`) and external-origin (`403`) requests.
- **Zero Shell Injection**: Validates target existence on disk and invokes native OS APIs directly.

---

## Troubleshooting & Uninstall

### macOS
```zsh
launchctl print "gui/$(id -u)/com.antigravity.file-opener" | grep -E "state =|pid ="
curl -sS http://127.0.0.1:59321/health
cat /tmp/antigravity-file-opener.log

# Completely uninstall
~/antigravity-file-opener/uninstall.sh
```

### Windows (PowerShell)
```powershell
Get-Process AntigravityFileOpener -ErrorAction SilentlyContinue
Invoke-RestMethod http://127.0.0.1:59321/health
Get-Content "$env:TEMP\antigravity-file-opener.log" -Tail 20

# Completely uninstall
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\antigravity-file-opener\windows\uninstall.ps1"
```
