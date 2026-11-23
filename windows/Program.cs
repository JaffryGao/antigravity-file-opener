using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace AntigravityFileOpener
{
    internal static class Program
    {
        private static readonly string LogPath = Path.Combine(Path.GetTempPath(), "antigravity-file-opener.log");
        private static readonly object LogLock = new object();

        [STAThread]
        private static void Main(string[] args)
        {
            bool createdNew;
            using (Mutex mutex = new Mutex(true, "Local\\AntigravityFileOpener_SingleInstance", out createdNew))
            {
                if (!createdNew)
                {
                    return;
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                string token = LoadOrCreateAuthToken();
                ContextMenuPresenter presenter = new ContextMenuPresenter();
                // 提前创建隐藏窗体句柄，确保主 UI 线程随时可响应异步菜单请求
                IntPtr unused = presenter.Handle;

                using (LocalActionServer server = new LocalActionServer(
                    LocalActionServer.DefaultPort,
                    token,
                    delegate(ResolvedFileTarget target) { ContextMenuPresenter.OpenWithDefaultApp(target); },
                    delegate(ResolvedFileTarget target) { ContextMenuPresenter.RevealInExplorer(target); },
                    delegate(ResolvedFileTarget target) { presenter.PresentMenu(target); },
                    WriteLog))
                {
                    if (!server.Start())
                    {
                        return;
                    }
                    Application.Run();
                }
            }
        }

        private static string LoadOrCreateAuthToken()
        {
            string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string dir = Path.Combine(Path.Combine(home, ".config"), "antigravity-file-opener");
            string tokenFile = Path.Combine(dir, "token");

            if (File.Exists(tokenFile))
            {
                string existing = File.ReadAllText(tokenFile, Encoding.UTF8).Trim();
                if (existing.Length >= 32)
                {
                    return existing;
                }
            }

            Directory.CreateDirectory(dir);
            byte[] bytes = new byte[32];
            using (RNGCryptoServiceProvider rng = new RNGCryptoServiceProvider())
            {
                rng.GetBytes(bytes);
            }

            StringBuilder sb = new StringBuilder(64);
            for (int i = 0; i < bytes.Length; i++)
            {
                sb.Append(bytes[i].ToString("x2"));
            }
            string token = sb.ToString();
            File.WriteAllText(tokenFile, token, new UTF8Encoding(false));
            return token;
        }

        private static void WriteLog(string message)
        {
            try
            {
                lock (LogLock)
                {
                    string line = "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] [AntigravityFileOpener] " + message + Environment.NewLine;
                    File.AppendAllText(LogPath, line, Encoding.UTF8);
                }
            }
            catch { }
        }
    }
}
