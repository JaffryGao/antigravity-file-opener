import Foundation

/// 从 Accessibility 属性中解析出的本地文件/目录目标
struct ResolvedFileTarget: Equatable, Sendable {
    let url: URL
    let isDirectory: Bool
    let sourceAttribute: String
    /// 若通过精确属性（AXURL/绝对路径）拿到则为 true；若通过文件名模糊兜底拿到则为 false
    let isExact: Bool

    var path: String {
        url.path
    }

    var displayName: String {
        url.lastPathComponent
    }

    var shortenedParentPath: String {
        let parent = url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if parent.hasPrefix(home) {
            return "~" + parent.dropFirst(home.count)
        }
        return parent
    }
}

/// 纯逻辑的文件链接与路径解析器（便于独立单元测试）
enum FileLinkParser {
    /// 用于抽象文件系统检查，方便单元测试注入
    typealias FileExistenceChecker = (_ path: String) -> (exists: Bool, isDirectory: Bool)

    static let defaultFileChecker: FileExistenceChecker = { path in
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return (exists, isDir.boolValue)
    }

    /// 常见本地文件扩展名白名单（用于识别胶囊内纯文件名）
    private static let knownExtensions: Set<String> = [
        "md", "markdown", "txt", "rtf", "pdf", "doc", "docx", "xls", "xlsx", "csv", "ppt", "pptx",
        "html", "htm", "css", "scss", "js", "jsx", "ts", "tsx", "json", "jsonc", "yaml", "yml",
        "xml", "toml", "ini", "env", "sql", "graphql", "proto",
        "swift", "m", "mm", "h", "hpp", "c", "cpp", "cc", "rs", "go", "py", "rb", "java", "kt",
        "kts", "php", "sh", "zsh", "bash", "ps1", "lua", "r", "dart", "vue", "svelte", "astro",
        "png", "jpg", "jpeg", "gif", "webp", "svg", "ico", "bmp", "tiff", "heic",
        "mp4", "mov", "mkv", "webm", "mp3", "wav", "m4a", "zip", "tar", "gz", "7z", "rar",
        "dmg", "pkg", "app", "ipa", "apk", "epub", "ofd", "log", "diff", "patch", "lock"
    ]

    /// 尝试从单个候选字符串（例如 AXURL / AXHelp / AXDescription / AXTitle / AXValue）中解析本地文件
    static func resolve(
        from rawString: String,
        sourceAttribute: String,
        fileChecker: FileExistenceChecker = defaultFileChecker
    ) -> ResolvedFileTarget? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. 优先尝试提取 file:// URI（可能整串就是 file://，也可能混在文本中）
        for fileURI in extractFileURIs(from: trimmed) {
            if let path = localPath(fromFileURIString: fileURI) {
                if let target = validateExistingPath(path, sourceAttribute: sourceAttribute, fileChecker: fileChecker) {
                    return target
                }
            }
        }

        // 如果是 http/https/mailto/javascript/customization 等非 file scheme，直接忽略
        if hasNonFileScheme(trimmed) {
            return nil
        }

        // 2. 尝试将整串当作绝对路径或 ~ 路径（剥离常见引号、括号、行号后缀如 #L10-L20 / :12:4）
        if let directPath = normalizePotentialPath(trimmed),
           let target = validateExistingPath(directPath, sourceAttribute: sourceAttribute, fileChecker: fileChecker) {
            return target
        }

        // 3. 尝试从一段说明文字中提取绝对路径（例如 "Open /Users/xxx/foo.md"）
        for candidate in extractAbsolutePaths(from: trimmed) {
            if let target = validateExistingPath(candidate, sourceAttribute: sourceAttribute, fileChecker: fileChecker) {
                return target
            }
        }

        return nil
    }

    /// 尝试直接从 CFURL / URL 对象解析本地文件
    static func resolve(
        from url: URL,
        sourceAttribute: String,
        fileChecker: FileExistenceChecker = defaultFileChecker
    ) -> ResolvedFileTarget? {
        guard url.isFileURL else { return nil }
        if let target = validateExistingPath(url.path, sourceAttribute: sourceAttribute, fileChecker: fileChecker) {
            return target
        }
        return resolve(from: url.absoluteString, sourceAttribute: sourceAttribute, fileChecker: fileChecker)
    }

    /// 从一组有序候选属性中解析第一个有效本地文件
    static func resolveFirst(
        from candidates: [(attribute: String, value: String)],
        fileChecker: FileExistenceChecker = defaultFileChecker
    ) -> ResolvedFileTarget? {
        for candidate in candidates {
            if let resolved = resolve(
                from: candidate.value,
                sourceAttribute: candidate.attribute,
                fileChecker: fileChecker
            ) {
                return resolved
            }
        }
        return nil
    }

    /// 判断一段短文本是否像文件胶囊中显示的文件名（用于 AX 树未暴露完整路径时的辅助识别）
    static func extractLikelyFileName(from rawText: String) -> String? {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 220 else { return nil }
        guard !trimmed.contains("\n"), !trimmed.contains("\r") else { return nil }
        guard !hasNonFileScheme(trimmed) else { return nil }

        // 去掉常见行号后缀（例如 foo.md:12 或 foo.md#L10-L20）
        let cleaned = stripLineAndFragmentSuffix(trimmed)

        // 不含路径分隔符或以斜杠结尾的目录暂不做纯名称猜测，防止把普通单词当文件
        guard !cleaned.contains("/") else { return nil }

        let ns = cleaned as NSString
        let ext = ns.pathExtension.lowercased()
        let base = ns.deletingPathExtension
        guard !base.isEmpty, !ext.isEmpty, knownExtensions.contains(ext) else {
            return nil
        }

        return cleaned
    }

    // MARK: - Internal Helpers

    private static func hasNonFileScheme(_ text: String) -> Bool {
        let lower = text.lowercased()
        let blockedPrefixes = [
            "http://", "https://", "mailto:", "javascript:", "data:",
            "conversation://", "customization://", "antigravity://", "sidecar://"
        ]
        return blockedPrefixes.contains { lower.hasPrefix($0) }
    }

    static func extractFileURIs(from text: String) -> [String] {
        guard text.localizedCaseInsensitiveContains("file://") else { return [] }
        var results: [String] = []

        // 若整串本身就是单个 file:// URI（允许文件名中含空格和括号），优先完整纳入
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\"'<>"))
        if trimmed.lowercased().hasPrefix("file://"), !trimmed.contains("\n"), !trimmed.contains("\r") {
            results.append(trimmed)
        }

        // 同时支持从长文本中提取 file:// URI（允许文件名内部带成对括号）
        let pattern = #"file://[^\s"'<>]+"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for match in regex.matches(in: text, options: [], range: range) {
                guard let swiftRange = Range(match.range, in: text) else { continue }
                let raw = String(text[swiftRange])
                if !results.contains(raw) {
                    results.append(raw)
                }
                let trimmedPunct = raw.trimmingCharacters(in: CharacterSet(charactersIn: ".,;!?)]"))
                if !trimmedPunct.isEmpty, !results.contains(trimmedPunct) {
                    results.append(trimmedPunct)
                }
            }
        }
        return results
    }

    static func localPath(fromFileURIString uriString: String) -> String? {
        // 先去除 #L12-L34 等 fragment
        let withoutFragment: String
        if let hashIndex = uriString.firstIndex(of: "#") {
            withoutFragment = String(uriString[..<hashIndex])
        } else {
            withoutFragment = uriString
        }

        // 先尝试标准 URL 解析
        if let url = URL(string: withoutFragment), url.isFileURL {
            return stripLineAndFragmentSuffix(url.path)
        }

        // 若含未编码中文或空格导致 URL(string:) 返回 nil，手动剥离 file:// 前缀并做百分号解码
        let prefix = "file://"
        guard withoutFragment.lowercased().hasPrefix(prefix) else { return nil }
        var rest = String(withoutFragment.dropFirst(prefix.count))
        if rest.lowercased().hasPrefix("localhost/") {
            rest = String(rest.dropFirst("localhost".count))
        }
        let decoded = rest.removingPercentEncoding ?? rest
        let cleaned = stripLineAndFragmentSuffix(decoded)
        guard cleaned.hasPrefix("/") else { return nil }
        return cleaned
    }

    private static func normalizePotentialPath(_ text: String) -> String? {
        var cleaned = text.trimmingCharacters(in: CharacterSet(charactersIn: " \t\n\r\"'`()[]<>"))
        cleaned = stripLineAndFragmentSuffix(cleaned)

        if cleaned.hasPrefix("~/") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            cleaned = home + String(cleaned.dropFirst(1))
        }

        guard cleaned.hasPrefix("/") else { return nil }
        return cleaned.removingPercentEncoding ?? cleaned
    }

    private static func extractAbsolutePaths(from text: String) -> [String] {
        // 常见 macOS 根路径起点，避免把普通文本中的斜杠词组误当路径
        let pattern = #"(?:~|/(?:Users|Applications|Volumes|Library|System|opt|tmp|var|private|etc))/[^\n\r"'<>`]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        var results: [String] = []
        for match in regex.matches(in: text, options: [], range: range) {
            guard let swiftRange = Range(match.range, in: text) else { continue }
            var candidate = String(text[swiftRange])
                .trimmingCharacters(in: CharacterSet(charactersIn: " \t.,;:!?)]}"))
            candidate = stripLineAndFragmentSuffix(candidate)
            if candidate.hasPrefix("~/") {
                let home = FileManager.default.homeDirectoryForCurrentUser.path
                candidate = home + String(candidate.dropFirst(1))
            }
            if !candidate.isEmpty {
                results.append(candidate)
            }
        }
        return results
    }

    static func stripLineAndFragmentSuffix(_ input: String) -> String {
        var value = input
        // 剥离 #L10 或 #L10-L20 等锚点
        if let range = value.range(of: #"#L?\d+(?:-L?\d+)?$"#, options: .regularExpression) {
            value.removeSubrange(range)
        } else if let hashIdx = value.firstIndex(of: "#") {
            value = String(value[..<hashIdx])
        }

        // 剥离 :12 或 :12:4 或 :12-20 行列号后缀
        if let range = value.range(of: #":\d+(?:[:-]\d+)?$"#, options: .regularExpression) {
            value.removeSubrange(range)
        }

        // 去掉多余尾部斜杠（保留根路径 "/"）
        while value.count > 1 && value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private static func validateExistingPath(
        _ rawPath: String,
        sourceAttribute: String,
        fileChecker: FileExistenceChecker
    ) -> ResolvedFileTarget? {
        let cleaned = stripLineAndFragmentSuffix(rawPath)
        guard cleaned.hasPrefix("/") else { return nil }
        let check = fileChecker(cleaned)
        guard check.exists else { return nil }
        let url = URL(fileURLWithPath: cleaned, isDirectory: check.isDirectory)
        return ResolvedFileTarget(
            url: url,
            isDirectory: check.isDirectory,
            sourceAttribute: sourceAttribute,
            isExact: true
        )
    }
}
