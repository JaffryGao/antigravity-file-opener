import AppKit
import Foundation

/// 原生 macOS 快捷菜单展示器（与 Finder 同源的 AppKit NSMenu / Liquid Glass 材质）
@MainActor
final class ContextMenuPresenter: NSObject {
    private var activeMenuHostWindow: NSPanel?
    private weak var activeMenu: NSMenu?
    private var actionHandlers: [Int: () -> Void] = [:]
    private var nextTag = 1

    /// 直接用 macOS 默认应用程序打开文件或文件夹
    func openWithDefaultApp(_ target: ResolvedFileTarget) {
        NSWorkspace.shared.open(target.url)
    }

    /// 用指定应用程序打开文件
    func open(_ target: ResolvedFileTarget, withApplicationAt appURL: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([target.url], withApplicationAt: appURL, configuration: config)
    }

    /// 在 Finder 中打开所在文件夹并高亮选中目标
    func revealInFinder(_ target: ResolvedFileTarget) {
        NSWorkspace.shared.activateFileViewerSelecting([target.url])
    }

    /// 复制文本到系统剪贴板
    func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// 在当前鼠标位置弹出原生 macOS NSMenu
    func presentMenu(for target: ResolvedFileTarget, previousApp: NSRunningApplication?) {
        activeMenu?.cancelTracking()
        actionHandlers.removeAll()
        nextTag = 1

        let menu = buildMenu(target: target, previousApp: previousApp)
        showPopupMenu(menu, previousApp: previousApp)
    }

    // MARK: - Menu Construction

    private func buildMenu(
        target: ResolvedFileTarget,
        previousApp: NSRunningApplication?
    ) -> NSMenu {
        let menu = NSMenu(title: target.displayName)
        menu.autoenablesItems = false

        // 文件名 + 真实文件图标（只读标题）
        let headerItem = NSMenuItem(title: target.displayName, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let fileIcon = NSWorkspace.shared.icon(forFile: target.path)
        fileIcon.size = NSSize(width: 16, height: 16)
        headerItem.image = fileIcon
        menu.addItem(headerItem)

        let dirItem = NSMenuItem(title: target.shortenedParentPath, action: nil, keyEquivalent: "")
        dirItem.isEnabled = false
        menu.addItem(dirItem)

        menu.addItem(.separator())

        // 1. 用默认应用程序打开（macOS 14+ 原生胶囊徽标提示 ⌘单击）
        let openTitle = target.isDirectory ? "用默认应用程序打开（Finder）" : "用默认应用程序打开"
        let openItem = makeActionItem(title: openTitle, systemSymbol: "arrow.up.forward.app") { [weak self] in
            self?.openWithDefaultApp(target)
        }
        if #available(macOS 14.0, *) {
            openItem.badge = NSMenuItemBadge(string: "⌘单击")
        }
        menu.addItem(openItem)

        // 2. 打开方式 › 子菜单（与 Finder 一致，仅对文件展示本机已注册应用）
        if !target.isDirectory, let openWithItem = buildOpenWithSubmenuItem(for: target) {
            menu.addItem(openWithItem)
        }

        // 3. 在 Finder 中显示
        menu.addItem(
            makeActionItem(title: "在 Finder 中显示", systemSymbol: "folder") { [weak self] in
                self?.revealInFinder(target)
            }
        )

        menu.addItem(.separator())

        // 4. 复制完整路径
        menu.addItem(
            makeActionItem(title: "复制完整路径", systemSymbol: "doc.on.doc") { [weak self] in
                self?.copyToPasteboard(target.path)
                previousApp?.activate(options: [])
            }
        )

        // 5. 复制文件名
        menu.addItem(
            makeActionItem(title: "复制文件名", systemSymbol: "textformat") { [weak self] in
                self?.copyToPasteboard(target.displayName)
                previousApp?.activate(options: [])
            }
        )

        return menu
    }

    private func buildOpenWithSubmenuItem(for target: ResolvedFileTarget) -> NSMenuItem? {
        let workspace = NSWorkspace.shared
        let defaultAppURL = workspace.urlForApplication(toOpen: target.url)?.standardizedFileURL
        let rawApps = workspace.urlsForApplications(toOpen: target.url)

        var seenPaths = Set<String>()
        var uniqueApps: [URL] = []

        // 默认应用排最前
        if let def = defaultAppURL {
            seenPaths.insert(def.path)
            uniqueApps.append(def)
        }

        let sortedOthers = rawApps
            .map(\.standardizedFileURL)
            .sorted { appDisplayName(for: $0).localizedCaseInsensitiveCompare(appDisplayName(for: $1)) == .orderedAscending }

        for appURL in sortedOthers {
            if seenPaths.insert(appURL.path).inserted {
                uniqueApps.append(appURL)
            }
            if uniqueApps.count >= 12 {
                break
            }
        }

        guard !uniqueApps.isEmpty else { return nil }

        let parentItem = NSMenuItem(title: "打开方式", action: nil, keyEquivalent: "")
        if let symbol = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "打开方式") {
            symbol.size = NSSize(width: 15, height: 15)
            parentItem.image = symbol
        }

        let submenu = NSMenu(title: "打开方式")
        submenu.autoenablesItems = false

        for (index, appURL) in uniqueApps.enumerated() {
            let isDefault = (defaultAppURL != nil && appURL.path == defaultAppURL?.path)
            let name = appDisplayName(for: appURL) + (isDefault ? "（默认）" : "")

            let item = makeActionItem(title: name, systemSymbol: nil) { [weak self] in
                self?.open(target, withApplicationAt: appURL)
            }
            let appIcon = workspace.icon(forFile: appURL.path)
            appIcon.size = NSSize(width: 16, height: 16)
            item.image = appIcon
            submenu.addItem(item)

            if isDefault && index == 0 && uniqueApps.count > 1 {
                submenu.addItem(.separator())
            }
        }

        parentItem.submenu = submenu
        return parentItem
    }

    private func appDisplayName(for appURL: URL) -> String {
        if let bundle = Bundle(url: appURL),
           let display = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String),
           !display.isEmpty {
            return display
        }
        return appURL.deletingPathExtension().lastPathComponent
    }

    private func makeActionItem(
        title: String,
        systemSymbol: String?,
        handler: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = true
        let tag = nextTag
        nextTag += 1
        item.tag = tag
        actionHandlers[tag] = handler

        if let systemSymbol,
           let symbol = NSImage(systemSymbolName: systemSymbol, accessibilityDescription: title) {
            symbol.size = NSSize(width: 15, height: 15)
            item.image = symbol
        }
        return item
    }

    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        let handler = actionHandlers[sender.tag]
        actionHandlers.removeAll()
        handler?()
    }

    // MARK: - Native Popup Presentation

    private func showPopupMenu(_ menu: NSMenu, previousApp: NSRunningApplication?) {
        let mouseLocation = NSEvent.mouseLocation

        let panel = NSPanel(
            contentRect: NSRect(x: mouseLocation.x, y: mouseLocation.y, width: 1, height: 1),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        activeMenuHostWindow = panel
        activeMenu = menu
        panel.orderFrontRegardless()

        NSApp.activate(ignoringOtherApps: true)

        let didSelect = menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: 0),
            in: panel.contentView
        )

        panel.orderOut(nil)
        activeMenuHostWindow = nil
        activeMenu = nil

        if !didSelect {
            actionHandlers.removeAll()
            previousApp?.activate(options: [])
        }
    }
}
