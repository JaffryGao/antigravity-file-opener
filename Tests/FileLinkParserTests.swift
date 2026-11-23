import Foundation

private var passedCount = 0
private var failedCount = 0

private func expect(_ condition: @autoclosure () -> Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition() {
        passedCount += 1
    } else {
        failedCount += 1
        fputs("❌ FAIL [\(file):\(line)] \(message)\n", stderr)
    }
}

private let mockFiles: [String: Bool] = [
    "/Users/demo/docs/20261122-1.1用户端迭代PRD.md": false,
    "/Users/demo/docs/my report (v2).pdf": false,
    "/Users/demo/docs/assets": true,
    "/Users/demo/project/index.html": false,
    "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop/notes.md": false
]

private let mockChecker: FileLinkParser.FileExistenceChecker = { path in
    if let isDir = mockFiles[path] {
        return (true, isDir)
    }
    return (false, false)
}

@main
struct FileLinkParserTestRunner {
    static func main() {
        // 1. 百分号编码的中文 file:// URI
        let encodedURI = "file:///Users/demo/docs/20261122-1.1%E7%94%A8%E6%88%B7%E7%AB%AF%E8%BF%AD%E4%BB%A3PRD.md#L10-L20"
        let r1 = FileLinkParser.resolve(from: encodedURI, sourceAttribute: "AXURL", fileChecker: mockChecker)
        expect(r1?.path == "/Users/demo/docs/20261122-1.1用户端迭代PRD.md", "应解码中文 file:// URI 并剥离 #L10-L20")
        expect(r1?.isDirectory == false, "Markdown 文件不应识别为目录")

        // 2. 含空格与括号的 file:// URL 对象与字符串
        let spacedURL = URL(fileURLWithPath: "/Users/demo/docs/my report (v2).pdf")
        let r2 = FileLinkParser.resolve(from: spacedURL, sourceAttribute: "AXURL", fileChecker: mockChecker)
        expect(r2?.path == "/Users/demo/docs/my report (v2).pdf", "应正确解析含空格与括号的 URL")
        let r2b = FileLinkParser.resolve(from: "file:///Users/demo/docs/my%20report%20(v2).pdf", sourceAttribute: "AXURL", fileChecker: mockChecker)
        expect(r2b?.path == "/Users/demo/docs/my report (v2).pdf", "应正确解析含空格与括号的 file:// 字符串")

        // 3. 未编码中文的 file:// 文本 + 行列号
        let rawURI = "file:///Users/demo/docs/20261122-1.1用户端迭代PRD.md:35:2"
        let r3 = FileLinkParser.resolve(from: rawURI, sourceAttribute: "AXHelp", fileChecker: mockChecker)
        expect(r3?.path == "/Users/demo/docs/20261122-1.1用户端迭代PRD.md", "应支持未编码中文 file:// 与 :35:2 后缀")

        // 4. 目录链接（含尾部斜杠）
        let dirURI = "file:///Users/demo/docs/assets/"
        let r4 = FileLinkParser.resolve(from: dirURI, sourceAttribute: "AXURL", fileChecker: mockChecker)
        expect(r4?.path == "/Users/demo/docs/assets", "应剥离目录尾部斜杠并匹配")
        expect(r4?.isDirectory == true, "assets 应识别为目录")

        // 5. 波浪号路径
        let tildePath = "~/Desktop/notes.md#L5"
        let r5 = FileLinkParser.resolve(from: tildePath, sourceAttribute: "AXDescription", fileChecker: mockChecker)
        expect(r5?.path == "\(FileManager.default.homeDirectoryForCurrentUser.path)/Desktop/notes.md", "应展开 ~/ 路径")

        // 6. 说明文本内嵌绝对路径
        let embedded = "点击打开 /Users/demo/project/index.html"
        let r6 = FileLinkParser.resolve(from: embedded, sourceAttribute: "AXHelp", fileChecker: mockChecker)
        expect(r6?.path == "/Users/demo/project/index.html", "应从说明文本中提取真实存在的绝对路径")

        // 7. 严格拒绝网页链接、自定义协议与不存在的文件
        expect(
            FileLinkParser.resolve(from: "https://example.com/20261122-1.1用户端迭代PRD.md", sourceAttribute: "AXURL", fileChecker: mockChecker) == nil,
            "不能将 https 链接误判为本地文件"
        )
        expect(
            FileLinkParser.resolve(from: "customization://my-plugin", sourceAttribute: "AXURL", fileChecker: mockChecker) == nil,
            "不能将 customization:// 误判为本地文件"
        )
        expect(
            FileLinkParser.resolve(from: "sidecar://android-cli-plugin/host.html", sourceAttribute: "AXURL", fileChecker: mockChecker) == nil,
            "不能将 sidecar:// 插件面板链接误判为本地文件"
        )
        expect(
            FileLinkParser.resolve(from: "file:///Users/demo/docs/not-exist.md", sourceAttribute: "AXURL", fileChecker: mockChecker) == nil,
            "不存在的本地文件必须返回 nil"
        )

        // 8. 纯文件名胶囊识别
        expect(
            FileLinkParser.extractLikelyFileName(from: "20261122-1.1用户端迭代PRD.md") == "20261122-1.1用户端迭代PRD.md",
            "应识别带 .md 扩展名的中文胶囊文件名"
        )
        expect(
            FileLinkParser.extractLikelyFileName(from: "用户端首页-1.html:18") == "用户端首页-1.html",
            "应识别带行号后缀的 html 胶囊文件名"
        )
        expect(
            FileLinkParser.extractLikelyFileName(from: "直接交付研发的文件") == nil,
            "普通中文标题不应识别为文件名"
        )
        expect(
            FileLinkParser.extractLikelyFileName(from: "https://antigravity.google/docs") == nil,
            "URL 不应识别为纯文件名"
        )

        print("测试完成: 通过 \(passedCount) 项，失败 \(failedCount) 项")
        exit(failedCount == 0 ? 0 : 1)
    }
}
