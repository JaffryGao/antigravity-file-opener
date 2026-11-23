using System;
using System.Collections.Generic;

namespace AntigravityFileOpener
{
    internal static class FileLinkParserTests
    {
        private static int _passed;
        private static int _failed;

        private static readonly Dictionary<string, bool> MockFiles = new Dictionary<string, bool>(StringComparer.OrdinalIgnoreCase)
        {
            { @"C:\Users\demo\docs\20261122-1.1用户端迭代PRD.md", false },
            { @"C:\Users\demo\docs\my report (v2).pdf", false },
            { @"C:\Users\demo\docs\assets", true },
            { @"D:\Work\project\index.html", false },
            { @"\\wsl.localhost\Ubuntu\home\dev\README.md", false }
        };

        private static bool MockChecker(string path, out bool isDirectory)
        {
            if (MockFiles.TryGetValue(path, out isDirectory))
            {
                return true;
            }
            isDirectory = false;
            return false;
        }

        private static void Expect(bool condition, string message)
        {
            if (condition)
            {
                _passed++;
            }
            else
            {
                _failed++;
                Console.Error.WriteLine("FAIL: " + message);
            }
        }

        private static int Main()
        {
            // 1. 百分号编码的中文 Windows file:/// URI + #L10-L20
            string encodedURI = "file:///C:/Users/demo/docs/20261122-1.1%E7%94%A8%E6%88%B7%E7%AB%AF%E8%BF%AD%E4%BB%A3PRD.md#L10-L20";
            ResolvedFileTarget r1 = FileLinkParser.Resolve(encodedURI, "LocalBridge", MockChecker);
            Expect(r1 != null && r1.FullPath == @"C:\Users\demo\docs\20261122-1.1用户端迭代PRD.md", "应解码中文 Windows file:/// URI 并剥离 #L10-L20");
            Expect(r1 != null && !r1.IsDirectory, "Markdown 文件不应识别为目录");

            // 2. 编码盘符冒号 (c%3A) + 空格括号
            string encodedDrive = "file:///c%3A/Users/demo/docs/my%20report%20(v2).pdf";
            ResolvedFileTarget r2 = FileLinkParser.Resolve(encodedDrive, "LocalBridge", MockChecker);
            Expect(r2 != null && r2.FullPath == @"c:\Users\demo\docs\my report (v2).pdf", "应支持 file:///c%3A/... 及含空格括号路径");

            // 3. 标准 Windows 路径 + 行列号后缀（盘符冒号不被误剥）
            ResolvedFileTarget r3 = FileLinkParser.Resolve(@"D:\Work\project\index.html:42:8", "LocalBridge", MockChecker);
            Expect(r3 != null && r3.FullPath == @"D:\Work\project\index.html", "应剥离 :42:8 同时保留盘符 D:");

            // 4. 目录路径（含尾部反斜杠）
            ResolvedFileTarget r4 = FileLinkParser.Resolve(@"C:\Users\demo\docs\assets\", "LocalBridge", MockChecker);
            Expect(r4 != null && r4.FullPath == @"C:\Users\demo\docs\assets" && r4.IsDirectory, "应正确识别目录并去除尾斜杠");

            // 5. WSL UNC file:// URI 与原生 UNC 路径
            ResolvedFileTarget r5 = FileLinkParser.Resolve("file://wsl.localhost/Ubuntu/home/dev/README.md#L3", "LocalBridge", MockChecker);
            Expect(r5 != null && r5.FullPath == @"\\wsl.localhost\Ubuntu\home\dev\README.md", "应支持 file://wsl.localhost/... 转为 UNC 路径");

            ResolvedFileTarget r6 = FileLinkParser.Resolve(@"\\wsl.localhost\Ubuntu\home\dev\README.md:12", "LocalBridge", MockChecker);
            Expect(r6 != null && r6.FullPath == @"\\wsl.localhost\Ubuntu\home\dev\README.md", "应支持原生 \\\\wsl.localhost\\... 路径与行号剥离");

            // 6. 严格拒绝非本地协议与不存在的路径
            Expect(FileLinkParser.Resolve("https://example.com/a.md", "LocalBridge", MockChecker) == null, "拒绝 https://");
            Expect(FileLinkParser.Resolve("sidecar://android-cli-plugin/host.html", "LocalBridge", MockChecker) == null, "拒绝 sidecar://");
            Expect(FileLinkParser.Resolve("customization://my-plugin", "LocalBridge", MockChecker) == null, "拒绝 customization://");
            Expect(FileLinkParser.Resolve(@"C:\Users\demo\docs\missing.md", "LocalBridge", MockChecker) == null, "拒绝不存在的本地文件");

            // 7. HTTP JSON 解析与 Origin 校验
            string parsed = LocalActionServer.ExtractJsonStringField("{\"path\":\"C:\\\\Users\\\\demo\\\\docs\\\\my report (v2).pdf\"}", "path");
            Expect(parsed == @"C:\Users\demo\docs\my report (v2).pdf", "应正确反转义 JSON 中的 Windows 反斜杠路径");
            Expect(LocalActionServer.IsAllowedOrigin("http://127.0.0.1:5387"), "允许 127.0.0.1 Origin");
            Expect(LocalActionServer.IsAllowedOrigin("vscode-file://vscode-app"), "允许 vscode-file:// Origin");
            Expect(!LocalActionServer.IsAllowedOrigin("https://evil.example"), "拒绝公网 Origin");

            Console.WriteLine("Windows 测试完成: 通过 " + _passed + " 项，失败 " + _failed + " 项");
            return _failed == 0 ? 0 : 1;
        }
    }
}
