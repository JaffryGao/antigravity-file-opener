import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var server: LocalActionServer?
    private let menuPresenter = ContextMenuPresenter()
    private let isSilent = CommandLine.arguments.contains("--silent")

    func applicationDidFinishLaunching(_ notification: Notification) {
        let token = loadOrCreateAuthToken()
        let presenter = self.menuPresenter
        let actionServer = LocalActionServer(port: LocalActionServer.defaultPort, authToken: token) { target in
            DispatchQueue.main.async {
                let previousApp = NSWorkspace.shared.frontmostApplication
                presenter.presentMenu(for: target, previousApp: previousApp)
            }
        }
        let started = actionServer.start()
        self.server = actionServer

        if !isSilent {
            setupStatusBar(started: started)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
    }

    private func loadOrCreateAuthToken() -> String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/antigravity-file-opener", isDirectory: true)
        let tokenFile = dir.appendingPathComponent("token")

        if let existing = try? String(contentsOf: tokenFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           existing.count >= 32 {
            return existing
        }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        try? token.write(to: tokenFile, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFile.path)
        return token
    }

    private func setupStatusBar(started: Bool) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            let symbolName = started ? "arrow.up.forward.app.fill" : "exclamationmark.triangle"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "AntigravityFileOpener") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "AG"
            }
        }

        let menu = NSMenu()
        let statusLine = NSMenuItem(
            title: started ? "✅ 本地打开服务运行中 (127.0.0.1:\(LocalActionServer.defaultPort))" : "⚠️ 本地端口启动失败",
            action: nil,
            keyEquivalent: ""
        )
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出 AntigravityFileOpener", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
