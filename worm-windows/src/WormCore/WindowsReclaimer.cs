using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Worm.Core;

public enum DeleteMode
{
    RecycleBin, // Recoverable (Default safe mode)
    Permanent   // Permanent file shredding
}

/// <summary>
/// Safe filesystem reclaimer. Supports moving files to the native Windows Recycle Bin
/// via SHFileOperation, with permanent deletion fallback and local TSV audit logging.
/// </summary>
public static class WindowsReclaimer
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct SHFILEOPSTRUCT
    {
        public IntPtr hwnd;
        [MarshalAs(UnmanagedType.U4)] public int wFunc;
        public string pFrom;
        public string pTo;
        public short fFlags;
        [MarshalAs(UnmanagedType.Bool)] public bool fAnyOperationsAborted;
        public IntPtr hNameMappings;
        public string lpszProgressTitle;
    }

    private const int FO_DELETE = 0x0003;
    private const int FOF_ALLOWUNDO = 0x0040; // Sends to Recycle Bin
    private const int FOF_NOCONFIRMATION = 0x0010; // No popup prompt
    private const int FOF_SILENT = 0x0004;

    [DllImport("shell32.dll", CharSet = CharSet.Auto)]
    private static extern int SHFileOperation(ref SHFILEOPSTRUCT FileOp);

    private static readonly object LogLock = new();

    public static async Task<bool> CleanTargetAsync(string targetPath, DeleteMode mode = DeleteMode.RecycleBin, CancellationToken ct = default)
    {
        if (WindowsSafetyPolicy.IsPathProtected(targetPath, out var reason))
        {
            LogAudit("BLOCKED", 0, targetPath, reason);
            return false;
        }

        return await Task.Run(() =>
        {
            ct.ThrowIfCancellationRequested();
            try
            {
                long size = 0;
                if (File.Exists(targetPath))
                {
                    size = new FileInfo(targetPath).Length;
                    if (mode == DeleteMode.RecycleBin && RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                    {
                        SendToRecycleBin(targetPath);
                    }
                    else
                    {
                        File.Delete(targetPath);
                    }
                }
                else if (Directory.Exists(targetPath))
                {
                    size = GetDirectorySize(targetPath);
                    if (mode == DeleteMode.RecycleBin && RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                    {
                        SendToRecycleBin(targetPath);
                    }
                    else
                    {
                        Directory.Delete(targetPath, true);
                    }
                }

                LogAudit("OK", size, targetPath, mode.ToString());
                return true;
            }
            catch (Exception ex)
            {
                LogAudit("FAILED", 0, targetPath, ex.Message);
                return false;
            }
        }, ct);
    }

    private static void SendToRecycleBin(string path)
    {
        var shf = new SHFILEOPSTRUCT
        {
            wFunc = FO_DELETE,
            fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION | FOF_SILENT,
            pFrom = path + '\0' + '\0' // SHFileOperation expects double null-terminated string
        };
        int result = SHFileOperation(ref shf);
        if (result != 0)
        {
            throw new IOException($"Recycle Bin operation failed with error code: {result}");
        }
    }

    private static long GetDirectorySize(string path)
    {
        long size = 0;
        try
        {
            var di = new DirectoryInfo(path);
            foreach (var fi in di.EnumerateFiles("*", SearchOption.AllDirectories))
            {
                try { size += fi.Length; } catch { }
            }
        }
        catch { }
        return size;
    }

    private static void LogAudit(string status, long size, string target, string note)
    {
        lock (LogLock)
        {
            try
            {
                var line = $"{DateTime.UtcNow:O}\t{status}\t{size}\t{target}\t{note}\n";
                File.AppendAllText(WindowsPaths.DeletionLog, line, Encoding.UTF8);
            }
            catch { }
        }
    }
}
