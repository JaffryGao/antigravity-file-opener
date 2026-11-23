using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;

namespace AntigravityFileOpener
{
    public sealed class LocalActionServer : IDisposable
    {
        public const int DefaultPort = 59321;

        private readonly int _port;
        private readonly string _authToken;
        private readonly Action<ResolvedFileTarget> _onOpen;
        private readonly Action<ResolvedFileTarget> _onReveal;
        private readonly Action<ResolvedFileTarget> _onMenu;
        private readonly Action<string> _logger;

        private TcpListener _listener;
        private volatile bool _running;
        private Thread _acceptThread;

        public LocalActionServer(
            int port,
            string authToken,
            Action<ResolvedFileTarget> onOpen,
            Action<ResolvedFileTarget> onReveal,
            Action<ResolvedFileTarget> onMenu,
            Action<string> logger)
        {
            _port = port;
            _authToken = authToken ?? string.Empty;
            _onOpen = onOpen;
            _onReveal = onReveal;
            _onMenu = onMenu;
            _logger = logger;
        }

        public bool Start()
        {
            try
            {
                _listener = new TcpListener(IPAddress.Loopback, _port);
                _listener.Start(32);
                _running = true;

                _acceptThread = new Thread(AcceptLoop);
                _acceptThread.IsBackground = true;
                _acceptThread.Name = "AntigravityFileOpener.Accept";
                _acceptThread.Start();

                Log("本地服务已就绪: http://127.0.0.1:" + _port);
                return true;
            }
            catch (Exception ex)
            {
                Log("绑定 127.0.0.1:" + _port + " 失败: " + ex.Message);
                return false;
            }
        }

        public void Stop()
        {
            _running = false;
            if (_listener != null)
            {
                try { _listener.Stop(); } catch { }
                _listener = null;
            }
        }

        public void Dispose()
        {
            Stop();
        }

        private void AcceptLoop()
        {
            while (_running && _listener != null)
            {
                try
                {
                    TcpClient client = _listener.AcceptTcpClient();
                    ThreadPool.QueueUserWorkItem(HandleClient, client);
                }
                catch
                {
                    if (!_running) break;
                }
            }
        }

        private void HandleClient(object state)
        {
            TcpClient client = (TcpClient)state;
            try
            {
                using (client)
                {
                    client.ReceiveTimeout = 2000;
                    client.SendTimeout = 2000;

                    using (NetworkStream stream = client.GetStream())
                    {
                        byte[] requestBytes = ReadHttpRequest(stream);
                        if (requestBytes == null || requestBytes.Length == 0)
                        {
                            SendResponse(stream, "400 Bad Request", null, "{\"ok\":false,\"error\":\"empty_request\"}");
                            return;
                        }

                        int headerEnd = FindHeaderEnd(requestBytes);
                        if (headerEnd < 0)
                        {
                            SendResponse(stream, "400 Bad Request", null, "{\"ok\":false,\"error\":\"malformed_request\"}");
                            return;
                        }

                        string headerText = Encoding.UTF8.GetString(requestBytes, 0, headerEnd);
                        string[] lines = headerText.Split(new string[] { "\r\n" }, StringSplitOptions.None);
                        if (lines.Length == 0)
                        {
                            SendResponse(stream, "400 Bad Request", null, "{\"ok\":false,\"error\":\"empty_request\"}");
                            return;
                        }

                        string[] parts = lines[0].Split(' ');
                        if (parts.Length < 2)
                        {
                            SendResponse(stream, "400 Bad Request", null, "{\"ok\":false,\"error\":\"invalid_request_line\"}");
                            return;
                        }

                        string method = parts[0].ToUpperInvariant();
                        string rawTarget = parts[1];
                        int queryIdx = rawTarget.IndexOf('?');
                        string pathOnly = queryIdx >= 0 ? rawTarget.Substring(0, queryIdx) : rawTarget;

                        Dictionary<string, string> headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
                        for (int i = 1; i < lines.Length; i++)
                        {
                            int colon = lines[i].IndexOf(':');
                            if (colon <= 0) continue;
                            string key = lines[i].Substring(0, colon).Trim();
                            string val = lines[i].Substring(colon + 1).Trim();
                            headers[key] = val;
                        }

                        string origin;
                        headers.TryGetValue("Origin", out origin);
                        if (!IsAllowedOrigin(origin))
                        {
                            SendResponse(stream, "403 Forbidden", null, "{\"ok\":false,\"error\":\"forbidden_origin\"}");
                            return;
                        }

                        if (method == "OPTIONS")
                        {
                            SendResponse(stream, "204 No Content", origin, string.Empty);
                            return;
                        }

                        if (method == "GET" && pathOnly == "/health")
                        {
                            SendResponse(stream, "200 OK", origin, "{\"ok\":true,\"service\":\"AntigravityFileOpener\"}");
                            return;
                        }

                        string token;
                        headers.TryGetValue("X-Agy-Token", out token);
                        if (string.IsNullOrEmpty(_authToken) || !ConstantTimeEquals(token ?? string.Empty, _authToken))
                        {
                            SendResponse(stream, "401 Unauthorized", origin, "{\"ok\":false,\"error\":\"unauthorized\"}");
                            return;
                        }

                        if (method != "POST" || (pathOnly != "/open" && pathOnly != "/reveal" && pathOnly != "/menu"))
                        {
                            SendResponse(stream, "404 Not Found", origin, "{\"ok\":false,\"error\":\"not_found\"}");
                            return;
                        }

                        int bodyStart = headerEnd + 4;
                        string bodyText = bodyStart < requestBytes.Length
                            ? Encoding.UTF8.GetString(requestBytes, bodyStart, requestBytes.Length - bodyStart)
                            : string.Empty;

                        string rawPath = ExtractJsonStringField(bodyText, "path");
                        if (string.IsNullOrEmpty(rawPath))
                        {
                            SendResponse(stream, "400 Bad Request", origin, "{\"ok\":false,\"error\":\"missing_path\"}");
                            return;
                        }

                        ResolvedFileTarget target = FileLinkParser.Resolve(rawPath, "LocalBridge");
                        if (target == null)
                        {
                            Log("拒绝不存在或非法路径: " + rawPath);
                            SendResponse(stream, "404 Not Found", origin, "{\"ok\":false,\"error\":\"path_not_found\"}");
                            return;
                        }

                        // 先返回 HTTP 200，避免前端 fetch 等待菜单关闭
                        SendResponse(stream, "200 OK", origin, "{\"ok\":true}");
                        Log("已执行 " + pathOnly + ": " + target.FullPath);

                        if (pathOnly == "/open" && _onOpen != null)
                        {
                            _onOpen(target);
                        }
                        else if (pathOnly == "/reveal" && _onReveal != null)
                        {
                            _onReveal(target);
                        }
                        else if (pathOnly == "/menu" && _onMenu != null)
                        {
                            _onMenu(target);
                        }
                    }
                }
            }
            catch
            {
                // 客户端提前断开等网络瞬态错误静默忽略
            }
        }

        private static byte[] ReadHttpRequest(NetworkStream stream)
        {
            using (MemoryStream ms = new MemoryStream())
            {
                byte[] chunk = new byte[4096];
                int headerEnd = -1;
                int expectedContentLength = 0;

                while (ms.Length < 65536)
                {
                    int read = stream.Read(chunk, 0, chunk.Length);
                    if (read <= 0) break;
                    ms.Write(chunk, 0, read);

                    byte[] snapshot = ms.ToArray();
                    if (headerEnd < 0)
                    {
                        headerEnd = FindHeaderEnd(snapshot);
                        if (headerEnd >= 0)
                        {
                            string headerStr = Encoding.UTF8.GetString(snapshot, 0, headerEnd);
                            expectedContentLength = ParseContentLength(headerStr);
                        }
                    }

                    if (headerEnd >= 0)
                    {
                        int bodyLength = snapshot.Length - (headerEnd + 4);
                        if (bodyLength >= expectedContentLength)
                        {
                            return snapshot;
                        }
                    }
                }

                return ms.ToArray();
            }
        }

        private static int FindHeaderEnd(byte[] data)
        {
            for (int i = 0; i <= data.Length - 4; i++)
            {
                if (data[i] == 13 && data[i + 1] == 10 && data[i + 2] == 13 && data[i + 3] == 10)
                {
                    return i;
                }
            }
            return -1;
        }

        private static int ParseContentLength(string headers)
        {
            string[] lines = headers.Split(new string[] { "\r\n" }, StringSplitOptions.None);
            for (int i = 0; i < lines.Length; i++)
            {
                if (lines[i].StartsWith("Content-Length:", StringComparison.OrdinalIgnoreCase))
                {
                    int len;
                    if (int.TryParse(lines[i].Substring(15).Trim(), out len) && len > 0)
                    {
                        return len;
                    }
                }
            }
            return 0;
        }

        public static bool IsAllowedOrigin(string origin)
        {
            if (string.IsNullOrEmpty(origin))
            {
                return true;
            }
            string lower = origin.ToLowerInvariant();
            if (lower == "null" ||
                lower.StartsWith("file://") ||
                lower.StartsWith("http://127.0.0.1") ||
                lower.StartsWith("https://127.0.0.1") ||
                lower.StartsWith("http://localhost") ||
                lower.StartsWith("https://localhost") ||
                lower.StartsWith("vscode-file://") ||
                lower.StartsWith("plugin://"))
            {
                return true;
            }
            return false;
        }

        public static string ExtractJsonStringField(string json, string fieldName)
        {
            if (string.IsNullOrEmpty(json) || string.IsNullOrEmpty(fieldName))
            {
                return null;
            }

            string keyToken = "\"" + fieldName + "\"";
            int keyPos = json.IndexOf(keyToken, StringComparison.Ordinal);
            if (keyPos < 0) return null;

            int colonPos = json.IndexOf(':', keyPos + keyToken.Length);
            if (colonPos < 0) return null;

            int i = colonPos + 1;
            while (i < json.Length && char.IsWhiteSpace(json[i])) i++;
            if (i >= json.Length || json[i] != '"') return null;

            i++;
            StringBuilder sb = new StringBuilder();
            while (i < json.Length)
            {
                char c = json[i++];
                if (c == '"')
                {
                    return sb.ToString();
                }
                if (c == '\\' && i < json.Length)
                {
                    char esc = json[i++];
                    switch (esc)
                    {
                        case '"': sb.Append('"'); break;
                        case '\\': sb.Append('\\'); break;
                        case '/': sb.Append('/'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'u':
                            if (i + 4 <= json.Length)
                            {
                                string hex = json.Substring(i, 4);
                                ushort code;
                                if (ushort.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out code))
                                {
                                    sb.Append((char)code);
                                    i += 4;
                                }
                            }
                            break;
                        default:
                            sb.Append(esc);
                            break;
                    }
                }
                else
                {
                    sb.Append(c);
                }
            }
            return null;
        }

        private static bool ConstantTimeEquals(string a, string b)
        {
            byte[] ba = Encoding.UTF8.GetBytes(a);
            byte[] bb = Encoding.UTF8.GetBytes(b);
            if (ba.Length != bb.Length) return false;
            int diff = 0;
            for (int i = 0; i < ba.Length; i++)
            {
                diff |= ba[i] ^ bb[i];
            }
            return diff == 0;
        }

        private static void SendResponse(NetworkStream stream, string status, string origin, string json)
        {
            byte[] bodyBytes = Encoding.UTF8.GetBytes(json ?? string.Empty);
            StringBuilder sb = new StringBuilder();
            sb.Append("HTTP/1.1 ").Append(status).Append("\r\n");
            sb.Append("Content-Type: application/json; charset=utf-8\r\n");
            sb.Append("Content-Length: ").Append(bodyBytes.Length).Append("\r\n");
            sb.Append("Connection: close\r\n");
            sb.Append("Cache-Control: no-store\r\n");
            if (!string.IsNullOrEmpty(origin))
            {
                sb.Append("Access-Control-Allow-Origin: ").Append(origin).Append("\r\n");
                sb.Append("Vary: Origin\r\n");
            }
            sb.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            sb.Append("Access-Control-Allow-Headers: Content-Type, X-Agy-Token\r\n");
            sb.Append("Access-Control-Allow-Private-Network: true\r\n");
            sb.Append("\r\n");

            byte[] headerBytes = Encoding.UTF8.GetBytes(sb.ToString());
            stream.Write(headerBytes, 0, headerBytes.Length);
            if (bodyBytes.Length > 0)
            {
                stream.Write(bodyBytes, 0, bodyBytes.Length);
            }
            stream.Flush();
        }

        private void Log(string msg)
        {
            if (_logger != null)
            {
                _logger(msg);
            }
        }
    }
}
