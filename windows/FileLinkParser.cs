using System;
using System.IO;
using System.Text.RegularExpressions;

namespace AntigravityFileOpener
{
    public sealed class ResolvedFileTarget
    {
        public string FullPath { get; private set; }
        public bool IsDirectory { get; private set; }
        public string SourceAttribute { get; private set; }

        public ResolvedFileTarget(string fullPath, bool isDirectory, string sourceAttribute)
        {
            FullPath = fullPath;
            IsDirectory = isDirectory;
            SourceAttribute = sourceAttribute;
        }

        public string DisplayName
        {
            get
            {
                string trimmed = FullPath.TrimEnd('\\', '/');
                if (trimmed.Length == 2 && trimmed[1] == ':')
                {
                    return trimmed + "\\";
                }
                string name = Path.GetFileName(trimmed);
                return string.IsNullOrEmpty(name) ? FullPath : name;
            }
        }

        public string ShortenedParentPath
        {
            get
            {
                string trimmed = FullPath.TrimEnd('\\', '/');
                string parent = Path.GetDirectoryName(trimmed);
                if (string.IsNullOrEmpty(parent))
                {
                    return trimmed;
                }
                string userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                if (!string.IsNullOrEmpty(userProfile) &&
                    parent.StartsWith(userProfile, StringComparison.OrdinalIgnoreCase))
                {
                    parent = "~" + parent.Substring(userProfile.Length);
                }
                if (parent.Length > 48)
                {
                    parent = parent.Substring(0, 20) + "..." + parent.Substring(parent.Length - 24);
                }
                return parent;
            }
        }
    }

    public delegate bool FileExistenceChecker(string path, out bool isDirectory);

    public static class FileLinkParser
    {
        private static readonly string[] BlockedSchemes = new string[]
        {
            "http://", "https://", "mailto:", "javascript:", "data:",
            "conversation://", "customization://", "antigravity://", "sidecar://"
        };

        private static readonly Regex DrivePrefixRegex = new Regex(@"^[a-zA-Z]:[\\/]", RegexOptions.Compiled);
        private static readonly Regex LeadingSlashDriveRegex = new Regex(@"^/[a-zA-Z]:[\\/]", RegexOptions.Compiled);
        private static readonly Regex LineSuffixRegex = new Regex(@":\d+(?:[:-]\d+)?$", RegexOptions.Compiled);
        private static readonly Regex FragmentLineRegex = new Regex(@"#L?\d+(?:-L?\d+)?$", RegexOptions.Compiled);

        public static bool DefaultFileChecker(string path, out bool isDirectory)
        {
            if (Directory.Exists(path))
            {
                isDirectory = true;
                return true;
            }
            if (File.Exists(path))
            {
                isDirectory = false;
                return true;
            }
            isDirectory = false;
            return false;
        }

        public static ResolvedFileTarget Resolve(string rawInput, string sourceAttribute)
        {
            return Resolve(rawInput, sourceAttribute, DefaultFileChecker);
        }

        public static ResolvedFileTarget Resolve(
            string rawInput,
            string sourceAttribute,
            FileExistenceChecker checker)
        {
            if (string.IsNullOrEmpty(rawInput))
            {
                return null;
            }

            string trimmed = rawInput.Trim();
            if (trimmed.Length == 0)
            {
                return null;
            }

            if (HasBlockedScheme(trimmed))
            {
                return null;
            }

            string normalized = NormalizeLocalPath(trimmed);
            if (string.IsNullOrEmpty(normalized))
            {
                return null;
            }

            bool isDirectory;
            if (!checker(normalized, out isDirectory))
            {
                return null;
            }

            return new ResolvedFileTarget(normalized, isDirectory, sourceAttribute);
        }

        public static string NormalizeLocalPath(string rawInput)
        {
            if (string.IsNullOrEmpty(rawInput))
            {
                return null;
            }

            string s = rawInput.Trim().Trim('"', '\'', '<', '>');
            if (s.Length == 0 || HasBlockedScheme(s))
            {
                return null;
            }

            // 去除 #L10-L20 或任意 #fragment
            int hashIdx = s.IndexOf('#');
            if (hashIdx >= 0)
            {
                s = s.Substring(0, hashIdx);
            }

            if (s.StartsWith("file://", StringComparison.OrdinalIgnoreCase))
            {
                string rest = s.Substring(7);
                if (rest.StartsWith("localhost/", StringComparison.OrdinalIgnoreCase))
                {
                    rest = rest.Substring(9);
                }
                else if (!rest.StartsWith("/"))
                {
                    // file://wsl.localhost/Ubuntu/home/... 或 file://server/share/...
                    string uncDecoded = SafeUnescape(rest).Replace('/', '\\');
                    string unc = "\\\\" + uncDecoded.TrimStart('\\');
                    return StripLineAndTrailingSlashes(unc);
                }

                s = SafeUnescape(rest);
                if (LeadingSlashDriveRegex.IsMatch(s))
                {
                    s = s.Substring(1);
                }
            }
            else
            {
                s = SafeUnescape(s);
            }

            // 支持 ~/ 路径展开到当前用户目录
            if (s.StartsWith("~/") || s.StartsWith("~\\"))
            {
                string home = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                if (!string.IsNullOrEmpty(home))
                {
                    s = home + s.Substring(1);
                }
            }

            if (LeadingSlashDriveRegex.IsMatch(s))
            {
                s = s.Substring(1);
            }

            // Windows 盘符路径 (C:\... 或 C:/...)
            if (DrivePrefixRegex.IsMatch(s))
            {
                s = s.Replace('/', '\\');
                return StripLineAndTrailingSlashes(s);
            }

            // Windows UNC / WSL 路径 (\\wsl.localhost\... 或 \\server\share\...)
            if (s.StartsWith("\\\\"))
            {
                s = "\\\\" + s.Substring(2).Replace('/', '\\');
                return StripLineAndTrailingSlashes(s);
            }

            return null;
        }

        private static bool HasBlockedScheme(string text)
        {
            for (int i = 0; i < BlockedSchemes.Length; i++)
            {
                if (text.StartsWith(BlockedSchemes[i], StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }
            return false;
        }

        private static string SafeUnescape(string value)
        {
            try
            {
                return Uri.UnescapeDataString(value);
            }
            catch
            {
                return value;
            }
        }

        private static string StripLineAndTrailingSlashes(string path)
        {
            string value = FragmentLineRegex.Replace(path, string.Empty);

            if (DrivePrefixRegex.IsMatch(value))
            {
                string drivePrefix = value.Substring(0, 2);
                string rest = LineSuffixRegex.Replace(value.Substring(2), string.Empty);
                value = drivePrefix + rest;
                while (value.Length > 3 && value.EndsWith("\\"))
                {
                    value = value.Substring(0, value.Length - 1);
                }
                return value;
            }

            if (value.StartsWith("\\\\"))
            {
                value = LineSuffixRegex.Replace(value, string.Empty);
                while (value.Length > 2 && value.EndsWith("\\"))
                {
                    value = value.Substring(0, value.Length - 1);
                }
                return value;
            }

            return value;
        }
    }
}
