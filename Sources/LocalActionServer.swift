import AppKit
import Darwin
import Foundation

/// 仅绑定 127.0.0.1 回环接口的极简原生文件打开服务（无外部网络暴露）
final class LocalActionServer: @unchecked Sendable {
    static let defaultPort: UInt16 = 59321

    private let port: UInt16
    private let authToken: String
    private let onMenuRequest: @Sendable (ResolvedFileTarget) -> Void
    private let queue = DispatchQueue(label: "local.antigravity.fileopener.server", qos: .userInitiated)
    private var serverSocket: Int32 = -1
    private var isRunning = false

    init(
        port: UInt16 = LocalActionServer.defaultPort,
        authToken: String,
        onMenuRequest: @escaping @Sendable (ResolvedFileTarget) -> Void
    ) {
        self.port = port
        self.authToken = authToken
        self.onMenuRequest = onMenuRequest
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else {
            log("创建监听 socket 失败: errno=\(errno)")
            return false
        }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        // 严格仅监听 127.0.0.1 回环地址，绝不暴露到局域网
        addr.sin_addr = in_addr(s_addr: INADDR_LOOPBACK.bigEndian)

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            log("绑定 127.0.0.1:\(port) 失败: errno=\(errno)")
            close(sock)
            return false
        }

        guard listen(sock, 32) == 0 else {
            log("listen 失败: errno=\(errno)")
            close(sock)
            return false
        }

        serverSocket = sock
        isRunning = true
        log("本地服务已就绪: http://127.0.0.1:\(port)")

        queue.async { [weak self] in
            self?.acceptLoop()
        }
        return true
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptLoop() {
        while isRunning && serverSocket >= 0 {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let client = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    accept(serverSocket, sockPtr, &clientLen)
                }
            }
            if client < 0 {
                if !isRunning { break }
                continue
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.handleClient(client)
            }
        }
    }

    private func handleClient(_ client: Int32) {
        defer { close(client) }

        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 4096)

        // 读取 HTTP 请求头与请求体（单次请求限制 64KB）
        var expectedBodyLength: Int? = nil
        var headerEndOffset: Int? = nil

        while buffer.count < 65536 {
            let n = recv(client, &chunk, chunk.count, 0)
            if n <= 0 { break }
            buffer.append(chunk, count: n)

            if headerEndOffset == nil, let range = buffer.range(of: Data("\r\n\r\n".utf8)) {
                headerEndOffset = range.upperBound
                if let headerStr = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: .utf8) {
                    expectedBodyLength = parseContentLength(from: headerStr)
                }
            }

            if let endOffset = headerEndOffset {
                let bodyLen = buffer.count - endOffset
                if bodyLen >= (expectedBodyLength ?? 0) {
                    break
                }
            }
        }

        guard let endOffset = headerEndOffset,
              let headerText = String(data: buffer.subdata(in: 0..<endOffset), encoding: .utf8) else {
            sendResponse(client, status: "400 Bad Request", origin: nil, json: #"{"ok":false,"error":"malformed_request"}"#)
            return
        }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse(client, status: "400 Bad Request", origin: nil, json: #"{"ok":false,"error":"empty_request"}"#)
            return
        }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(client, status: "400 Bad Request", origin: nil, json: #"{"ok":false,"error":"invalid_request_line"}"#)
            return
        }

        let method = String(parts[0]).uppercased()
        let rawTarget = String(parts[1])
        let pathOnly = rawTarget.split(separator: "?").first.map(String.init) ?? rawTarget

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
            let val = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            headers[key] = val
        }

        let origin = headers["origin"]
        guard isAllowedOrigin(origin) else {
            sendResponse(client, status: "403 Forbidden", origin: nil, json: #"{"ok":false,"error":"forbidden_origin"}"#)
            return
        }

        // CORS 预检请求
        if method == "OPTIONS" {
            sendResponse(client, status: "204 No Content", origin: origin, json: "")
            return
        }

        // 健康检查
        if method == "GET" && pathOnly == "/health" {
            sendResponse(client, status: "200 OK", origin: origin, json: #"{"ok":true,"service":"AntigravityFileOpener"}"#)
            return
        }

        // 严格鉴权：所有动作接口必须携带本地随机 Token
        let token = headers["x-agy-token"] ?? ""
        guard !authToken.isEmpty && constantTimeEquals(token, authToken) else {
            sendResponse(client, status: "401 Unauthorized", origin: origin, json: #"{"ok":false,"error":"unauthorized"}"#)
            return
        }

        guard method == "POST", pathOnly == "/open" || pathOnly == "/reveal" || pathOnly == "/menu" else {
            sendResponse(client, status: "404 Not Found", origin: origin, json: #"{"ok":false,"error":"not_found"}"#)
            return
        }

        let bodyData = buffer.subdata(in: endOffset..<buffer.count)
        guard let payload = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let rawPath = payload["path"] as? String else {
            sendResponse(client, status: "400 Bad Request", origin: origin, json: #"{"ok":false,"error":"missing_path"}"#)
            return
        }

        guard let target = FileLinkParser.resolve(from: rawPath, sourceAttribute: "LocalBridge") else {
            log("拒绝不存在或非法路径: \(rawPath)")
            sendResponse(client, status: "404 Not Found", origin: origin, json: #"{"ok":false,"error":"path_not_found"}"#)
            return
        }

        // 先返回 HTTP 200，避免阻塞前端 fetch，再异步在主线程执行原生动作或弹出 NSMenu
        sendResponse(client, status: "200 OK", origin: origin, json: #"{"ok":true}"#)
        log("已执行 \(pathOnly): \(target.path)")

        if pathOnly == "/menu" {
            onMenuRequest(target)
        } else {
            DispatchQueue.main.async {
                if pathOnly == "/open" {
                    NSWorkspace.shared.open(target.url)
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([target.url])
                }
            }
        }
    }

    // MARK: - Helpers

    private func isAllowedOrigin(_ origin: String?) -> Bool {
        guard let origin, !origin.isEmpty else { return true }
        let lower = origin.lowercased()
        if lower == "null" || lower.hasPrefix("file://") {
            return true
        }
        if lower.hasPrefix("http://127.0.0.1") || lower.hasPrefix("https://127.0.0.1") ||
            lower.hasPrefix("http://localhost") || lower.hasPrefix("https://localhost") ||
            lower.hasPrefix("vscode-file://") || lower.hasPrefix("plugin://") {
            return true
        }
        return false
    }

    private func parseContentLength(from headers: String) -> Int {
        for line in headers.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let value = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                return Int(value) ?? 0
            }
        }
        return 0
    }

    private func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let bytesA = Array(a.utf8)
        let bytesB = Array(b.utf8)
        guard bytesA.count == bytesB.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<bytesA.count {
            diff |= bytesA[i] ^ bytesB[i]
        }
        return diff == 0
    }

    private func sendResponse(_ client: Int32, status: String, origin: String?, json: String) {
        let bodyData = Data(json.utf8)
        var headerLines = [
            "HTTP/1.1 \(status)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(bodyData.count)",
            "Connection: close",
            "Cache-Control: no-store"
        ]
        if let origin, !origin.isEmpty {
            headerLines.append("Access-Control-Allow-Origin: \(origin)")
            headerLines.append("Vary: Origin")
        }
        headerLines.append("Access-Control-Allow-Methods: GET, POST, OPTIONS")
        headerLines.append("Access-Control-Allow-Headers: Content-Type, X-Agy-Token")
        headerLines.append("Access-Control-Allow-Private-Network: true")

        var payload = Data((headerLines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        payload.append(bodyData)

        payload.withUnsafeBytes { rawBuf in
            guard let base = rawBuf.baseAddress else { return }
            var totalSent = 0
            while totalSent < payload.count {
                let sent = send(client, base.advanced(by: totalSent), payload.count - totalSent, 0)
                if sent <= 0 { break }
                totalSent += sent
            }
        }
    }

    private func log(_ message: String) {
        fputs("[AntigravityFileOpener] \(message)\n", stdout)
        fflush(stdout)
    }
}
