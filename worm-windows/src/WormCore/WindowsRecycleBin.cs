using System;
using System.IO;
using System.Runtime.InteropServices;

namespace Worm.Core;

/// <summary>
/// Recycle Bin measurement and emptying via the Win32 Shell API.
///
/// This is the Windows analogue of the macOS Trash category. It is deliberately
/// not expressed as a scan rule: the Recycle Bin has no filesystem path, so it
/// cannot be walked or guarded by the path-based safety policy. It is measured
/// and emptied through the shell instead, and every emptying action is written
/// to the same audit log as everything else.
/// </summary>
public static class WindowsRecycleBin
{
    // SHQueryRecycleBinW
    private const uint SHERB_NOCONFIRMATION = 0x00000080;
    private const uint SHERB_NOERRORUI = 0x00000400;
    private const uint SHERB_NOPROGRESSUI = 0x00000200;

    private const int MaxChar = 260;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHQUERYRBINFO
    {
        public long cbSize;
        public long i64NumItems;
        public long i64Size;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct SHFILEOPSTRUCT
    {
        public IntPtr hwnd;
        public uint wFunc;
        [MarshalAs(UnmanagedType.LPWStr)] public string? pFrom;
        [MarshalAs(UnmanagedType.LPWStr)] public string? pTo;
        public uint fFlags;
        [MarshalAs(UnmanagedType.Bool)] public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        [MarshalAs(UnmanagedType.LPWStr)] public string? lpszProgressTitle;
    }

    private const uint FO_DELETE = 0x0003;

    [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
    private static extern long SHQueryRecycleBinW(
        [MarshalAs(UnmanagedType.LPWStr)] string pszRootPath,
        ref SHQUERYRBINFO pmetaData,
        [MarshalAs(UnmanagedType.LPWStr)] string? pszComputerName,
        int cbComputerNameMax);

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern int SHFileOperationW(ref SHFILEOPSTRUCT lpFileOp);

    public readonly record struct RecycleBinInfo(long ItemCount, long SizeBytes, bool Valid)
    {
        public string FormattedSize
        {
            get
            {
                string[] suffix = { "B", "KB", "MB", "GB", "TB" };
                int counter = 0;
                double number = SizeBytes;
                while (Math.Round(number / 1024) >= 1 && counter < suffix.Length - 1)
                {
                    number /= 1024;
                    counter++;
                }
                return $"{number:n1} {suffix[counter]}";
            }
        }
    }

    /// <summary>
    /// Measures the Recycle Bin for one root, or across all fixed drives when
    /// root is null. Never throws: an unreadable volume reports Valid=false so
    /// the UI can say so rather than showing a wrong zero.
    /// </summary>
    public static RecycleBinInfo Measure(string? root = null)
    {
        try
        {
            var info = new SHQUERYRBINFO
            {
                cbSize = Marshal.SizeOf<SHQUERYRBINFO>()
            };

            var result = SHQueryRecycleBinW(root ?? string.Empty, ref info, null, 0);
            if (result != 0) return new RecycleBinInfo(0, 0, false);

            return new RecycleBinInfo(Math.Max(0, info.i64NumItems), Math.Max(0, info.i64Size), true);
        }
        catch
        {
            return new RecycleBinInfo(0, 0, false);
        }
    }

    /// <summary>Total across every fixed drive.</summary>
    public static RecycleBinInfo MeasureAll()
    {
        long items = 0, size = 0;
        bool any = false;

        foreach (var root in EnumerateRoots())
        {
            var one = Measure(root);
            if (!one.Valid) continue;
            any = true;
            items += one.ItemCount;
            size += one.SizeBytes;
        }

        return new RecycleBinInfo(items, size, any);
    }

    private static IEnumerable<string> EnumerateRoots()
    {
        var drives = DriveInfo.GetDrives();
        foreach (var d in drives)
        {
            if (!d.IsReady) continue;
            var format = d.DriveFormat.ToLowerInvariant();
            if (format != "ntfs" && format != "fat32" && format != "exfat") continue;
            string? root = null;
            try { root = Path.GetPathRoot(d.Name); }
            catch { /* unreadable volume */ }
            if (!string.IsNullOrEmpty(root)) yield return root!;
        }
    }

    /// <summary>
    /// Empties the Recycle Bin for a root (or all drives when null). This is the
    /// one operation in Worm that is unconditionally permanent, matching
    /// "Empty Trash" on macOS, and it is recorded in the audit log.
    /// </summary>
    public static bool Empty(out string error, string? root = null)
    {
        error = string.Empty;
        try
        {
            var op = new SHFILEOPSTRUCT
            {
                wFunc = FO_DELETE,
                // pFrom must be a double-null-terminated list of paths.
                pFrom = (root ?? string.Empty) + "\0\0",
                fFlags = SHERB_NOCONFIRMATION | SHERB_NOERRORUI | SHERB_NOPROGRESSUI
            };

            var result = SHFileOperationW(ref op);
            if (result != 0)
            {
                error = $"Shell operation failed with code {result}";
                return false;
            }

            WindowsAuditLog.Record("OK", 0, root ?? "(all volumes)", "RecycleBin.Emptyed.Permanent");
            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            WindowsAuditLog.Record("FAILED", 0, root ?? "(all volumes)", ex.Message);
            return false;
        }
    }
}
