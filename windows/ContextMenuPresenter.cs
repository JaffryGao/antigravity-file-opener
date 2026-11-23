using System;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace AntigravityFileOpener
{
    /// <summary>
    /// Windows 原生右键菜单展示器与系统文件操作封装（Win11 DWM 圆角 + 深浅色跟随系统 + 原生打开方式弹窗）
    /// </summary>
    public sealed class ContextMenuPresenter : Form
    {
        private const int DWMWA_WINDOW_CORNER_PREFERENCE = 33;
        private const int DWMWCP_ROUND = 2;
        private const int WM_NULL = 0x0000;
        private const uint SHGFI_ICON = 0x000000100;
        private const uint SHGFI_SMALLICON = 0x000000001;
        private const uint SHGFI_USEFILEATTRIBUTES = 0x000000010;
        private const uint FILE_ATTRIBUTE_DIRECTORY = 0x00000010;
        private const uint FILE_ATTRIBUTE_NORMAL = 0x00000080;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct SHFILEINFO
        {
            public IntPtr hIcon;
            public int iIcon;
            public uint dwAttributes;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)]
            public string szDisplayName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 80)]
            public string szTypeName;
        }

        [DllImport("user32.dll")]
        private static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

        [DllImport("dwmapi.dll")]
        private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern IntPtr SHGetFileInfo(
            string pszPath,
            uint dwFileAttributes,
            ref SHFILEINFO psfi,
            uint cbFileInfo,
            uint uFlags);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SHParseDisplayName(
            string name,
            IntPtr bindingContext,
            out IntPtr pidl,
            uint sfgaoIn,
            out uint psfgaoOut);

        [DllImport("shell32.dll")]
        private static extern int SHOpenFolderAndSelectItems(
            IntPtr pidlFolder,
            uint cidl,
            IntPtr[] apidl,
            uint dwFlags);

        [DllImport("ole32.dll")]
        private static extern void CoTaskMemFree(IntPtr pv);

        private ContextMenuStrip _activeMenu;

        public ContextMenuPresenter()
        {
            ShowInTaskbar = false;
            FormBorderStyle = FormBorderStyle.FixedToolWindow;
            StartPosition = FormStartPosition.Manual;
            Location = new Point(-32000, -32000);
            Size = new Size(1, 1);
            Opacity = 0;
        }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                // WS_EX_TOOLWINDOW 避免出现在 Alt+Tab 任务切换列表
                cp.ExStyle |= 0x80;
                return cp;
            }
        }

        public static void OpenWithDefaultApp(ResolvedFileTarget target)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo(target.FullPath);
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
        }

        public static void OpenWithDialog(ResolvedFileTarget target)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("rundll32.exe", "shell32.dll,OpenAs_RunDLL " + target.FullPath);
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
        }

        public static void RevealInExplorer(ResolvedFileTarget target)
        {
            IntPtr pidl = IntPtr.Zero;
            try
            {
                uint attrs;
                int hr = SHParseDisplayName(target.FullPath, IntPtr.Zero, out pidl, 0, out attrs);
                if (hr == 0 && pidl != IntPtr.Zero)
                {
                    if (SHOpenFolderAndSelectItems(pidl, 0, null, 0) == 0)
                    {
                        return;
                    }
                }
            }
            catch { }
            finally
            {
                if (pidl != IntPtr.Zero)
                {
                    CoTaskMemFree(pidl);
                }
            }

            // 兜底：调用 explorer.exe /select
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("explorer.exe", "/select,\"" + target.FullPath + "\"");
                psi.UseShellExecute = true;
                Process.Start(psi);
            }
            catch { }
        }

        public static void CopyText(string text)
        {
            try
            {
                Clipboard.SetText(text);
            }
            catch { }
        }

        public void PresentMenu(ResolvedFileTarget target)
        {
            if (InvokeRequired)
            {
                BeginInvoke(new Action<ResolvedFileTarget>(PresentMenu), target);
                return;
            }

            if (_activeMenu != null)
            {
                try { _activeMenu.Close(); } catch { }
                _activeMenu.Dispose();
                _activeMenu = null;
            }

            IntPtr previousWindow = GetForegroundWindow();
            bool isDark = IsSystemDarkTheme();

            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Font = new Font("Microsoft YaHei UI", 9.5f, FontStyle.Regular);
            menu.ShowImageMargin = true;
            menu.ShowCheckMargin = false;
            menu.Padding = new Padding(4, 5, 4, 5);
            menu.Renderer = new ModernMenuRenderer(isDark);
            menu.BackColor = isDark ? Color.FromArgb(42, 42, 46) : Color.FromArgb(250, 250, 252);
            menu.ForeColor = isDark ? Color.FromArgb(245, 245, 247) : Color.FromArgb(28, 28, 30);

            // 文件名 + 真实系统图标（只读标题）
            ToolStripMenuItem headerItem = new ToolStripMenuItem(target.DisplayName);
            headerItem.Enabled = false;
            headerItem.Image = ExtractFileIconBitmap(target.FullPath, target.IsDirectory);
            menu.Items.Add(headerItem);

            ToolStripMenuItem dirItem = new ToolStripMenuItem(target.ShortenedParentPath);
            dirItem.Enabled = false;
            dirItem.Font = new Font("Microsoft YaHei UI", 8.2f, FontStyle.Regular);
            menu.Items.Add(dirItem);

            menu.Items.Add(new ToolStripSeparator());

            // 1. 用默认应用程序打开
            string openTitle = target.IsDirectory ? "用默认应用程序打开（资源管理器）" : "用默认应用程序打开";
            ToolStripMenuItem openItem = new ToolStripMenuItem(openTitle);
            openItem.ShortcutKeyDisplayString = "Ctrl+单击";
            openItem.Click += delegate { OpenWithDefaultApp(target); };
            menu.Items.Add(openItem);

            // 2. 打开方式…（唤起 Windows 原生应用选择框）
            if (!target.IsDirectory)
            {
                ToolStripMenuItem openWithItem = new ToolStripMenuItem("打开方式…");
                openWithItem.Click += delegate { OpenWithDialog(target); };
                menu.Items.Add(openWithItem);
            }

            // 3. 在文件资源管理器中显示
            ToolStripMenuItem revealItem = new ToolStripMenuItem("在文件资源管理器中显示");
            revealItem.Click += delegate { RevealInExplorer(target); };
            menu.Items.Add(revealItem);

            menu.Items.Add(new ToolStripSeparator());

            // 4. 复制完整路径
            ToolStripMenuItem copyPathItem = new ToolStripMenuItem("复制完整路径");
            copyPathItem.Click += delegate
            {
                CopyText(target.FullPath);
                RestoreWindowFocus(previousWindow);
            };
            menu.Items.Add(copyPathItem);

            // 5. 复制文件名
            ToolStripMenuItem copyNameItem = new ToolStripMenuItem("复制文件名");
            copyNameItem.Click += delegate
            {
                CopyText(target.DisplayName);
                RestoreWindowFocus(previousWindow);
            };
            menu.Items.Add(copyNameItem);

            menu.Opened += delegate
            {
                try
                {
                    int pref = DWMWCP_ROUND;
                    DwmSetWindowAttribute(menu.Handle, DWMWA_WINDOW_CORNER_PREFERENCE, ref pref, sizeof(int));
                }
                catch { }
            };

            menu.Closed += delegate(object s, ToolStripDropDownClosedEventArgs e)
            {
                if (e.CloseReason != ToolStripDropDownCloseReason.ItemClicked)
                {
                    RestoreWindowFocus(previousWindow);
                }
            };

            _activeMenu = menu;

            // Win32 标准无窗体弹出菜单焦点协议：确保点击外部自动收起
            if (!IsHandleCreated)
            {
                IntPtr unused = Handle;
            }
            SetForegroundWindow(Handle);
            menu.Show(Cursor.Position);
            PostMessage(Handle, WM_NULL, IntPtr.Zero, IntPtr.Zero);
        }

        private static void RestoreWindowFocus(IntPtr hwnd)
        {
            if (hwnd != IntPtr.Zero)
            {
                try { SetForegroundWindow(hwnd); } catch { }
            }
        }

        private static bool IsSystemDarkTheme()
        {
            try
            {
                object val = Registry.GetValue(
                    @"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize",
                    "AppsUseLightTheme",
                    1);
                if (val is int)
                {
                    return ((int)val) == 0;
                }
            }
            catch { }
            return false;
        }

        private static Image ExtractFileIconBitmap(string path, bool isDirectory)
        {
            SHFILEINFO info = new SHFILEINFO();
            uint flags = SHGFI_ICON | SHGFI_SMALLICON | SHGFI_USEFILEATTRIBUTES;
            uint attrs = isDirectory ? FILE_ATTRIBUTE_DIRECTORY : FILE_ATTRIBUTE_NORMAL;
            IntPtr res = SHGetFileInfo(path, attrs, ref info, (uint)Marshal.SizeOf(info), flags);
            if (res != IntPtr.Zero && info.hIcon != IntPtr.Zero)
            {
                try
                {
                    using (Icon ico = Icon.FromHandle(info.hIcon))
                    {
                        return new Bitmap(ico.ToBitmap(), new Size(16, 16));
                    }
                }
                finally
                {
                    DestroyIcon(info.hIcon);
                }
            }
            return null;
        }

        private sealed class ModernMenuRenderer : ToolStripProfessionalRenderer
        {
            private readonly bool _dark;

            public ModernMenuRenderer(bool dark)
                : base(new ModernColorTable(dark))
            {
                _dark = dark;
                RoundedEdges = true;
            }

            protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e)
            {
                if (!e.Item.Enabled)
                {
                    e.TextColor = _dark ? Color.FromArgb(156, 156, 164) : Color.FromArgb(120, 120, 128);
                }
                else
                {
                    e.TextColor = _dark ? Color.FromArgb(245, 245, 247) : Color.FromArgb(28, 28, 30);
                }
                base.OnRenderItemText(e);
            }

            protected override void OnRenderMenuItemBackground(ToolStripItemRenderEventArgs e)
            {
                if (e.Item.Selected && e.Item.Enabled)
                {
                    Rectangle rect = new Rectangle(4, 1, e.Item.Width - 8, e.Item.Height - 2);
                    Color hoverBg = _dark ? Color.FromArgb(62, 62, 68) : Color.FromArgb(232, 236, 244);
                    using (SolidBrush brush = new SolidBrush(hoverBg))
                    {
                        e.Graphics.FillRectangle(brush, rect);
                    }
                }
            }

            protected override void OnRenderSeparator(ToolStripSeparatorRenderEventArgs e)
            {
                int y = e.Item.Height / 2;
                Color sepColor = _dark ? Color.FromArgb(64, 64, 70) : Color.FromArgb(226, 226, 230);
                using (Pen pen = new Pen(sepColor))
                {
                    e.Graphics.DrawLine(pen, 10, y, e.Item.Width - 10, y);
                }
            }
        }

        private sealed class ModernColorTable : ProfessionalColorTable
        {
            private readonly bool _dark;

            public ModernColorTable(bool dark)
            {
                _dark = dark;
            }

            public override Color ToolStripDropDownBackground
            {
                get { return _dark ? Color.FromArgb(42, 42, 46) : Color.FromArgb(250, 250, 252); }
            }

            public override Color ImageMarginGradientBegin
            {
                get { return ToolStripDropDownBackground; }
            }

            public override Color ImageMarginGradientMiddle
            {
                get { return ToolStripDropDownBackground; }
            }

            public override Color ImageMarginGradientEnd
            {
                get { return ToolStripDropDownBackground; }
            }

            public override Color MenuBorder
            {
                get { return _dark ? Color.FromArgb(72, 72, 78) : Color.FromArgb(212, 212, 218); }
            }
        }
    }
}
