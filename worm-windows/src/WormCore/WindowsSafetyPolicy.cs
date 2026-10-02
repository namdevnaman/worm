using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace Worm.Core;

public enum RiskLevel
{
    Regenerable,  // Safe cache, temporary files, build artifacts (Default safe clean)
    ReDownload,   // Package manager caches (npm, pip, cargo, nuget)
    UserData,     // Important data (Requires explicit confirmation)
    Unsafe        // Blocked by system safety policy
}

/// <summary>
/// Strict fail-safe policy preventing destruction of Windows OS, active personal directories, and critical system state.
/// </summary>
public static class WindowsSafetyPolicy
{
    private static readonly HashSet<string> HardBlockedRoots = new(StringComparer.OrdinalIgnoreCase)
    {
        WindowsPaths.WindowsDir,
        Path.Combine(WindowsPaths.WindowsDir, "System32"),
        Path.Combine(WindowsPaths.WindowsDir, "SysWOW64"),
        WindowsPaths.ProgramFiles,
        WindowsPaths.ProgramFilesX86,
        Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments),
        Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
        Environment.GetFolderPath(Environment.SpecialFolder.MyPictures),
        Environment.GetFolderPath(Environment.SpecialFolder.MyMusic),
        Environment.GetFolderPath(Environment.SpecialFolder.MyVideos),
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) // Never allow deleting the user root
    };

    private static readonly List<string> UserProtectList = new();
    private static readonly object LockObj = new();

    static WindowsSafetyPolicy()
    {
        ReloadUserProtectList();
    }

    public static void ReloadUserProtectList()
    {
        lock (LockObj)
        {
            UserProtectList.Clear();
            if (File.Exists(WindowsPaths.ProtectFile))
            {
                try
                {
                    var lines = File.ReadAllLines(WindowsPaths.ProtectFile);
                    foreach (var line in lines)
                    {
                        var trimmed = line.Trim();
                        if (!string.IsNullOrEmpty(trimmed) && !trimmed.StartsWith("#"))
                        {
                            UserProtectList.Add(WindowsPaths.Expand(trimmed));
                        }
                    }
                }
                catch { }
            }
        }
    }

    public static IReadOnlyList<string> GetProtectedPaths()
    {
        lock (LockObj) return UserProtectList.ToList();
    }

    public static void AddProtectedPath(string path)
    {
        var expanded = WindowsPaths.Expand(path);
        lock (LockObj)
        {
            if (!UserProtectList.Contains(expanded, StringComparer.OrdinalIgnoreCase))
            {
                UserProtectList.Add(expanded);
                try
                {
                    File.AppendAllLines(WindowsPaths.ProtectFile, new[] { expanded });
                }
                catch { }
            }
        }
    }

    public static void RemoveProtectedPath(string path)
    {
        var expanded = WindowsPaths.Expand(path);
        lock (LockObj)
        {
            UserProtectList.RemoveAll(p => p.Equals(expanded, StringComparison.OrdinalIgnoreCase));
            try
            {
                File.WriteAllLines(WindowsPaths.ProtectFile, UserProtectList);
            }
            catch { }
        }
    }

    /// <summary>
    /// Checks if a path is protected either by hard system safety rules or user whitelist.
    /// </summary>
    public static bool IsPathProtected(string targetPath, out string reason)
    {
        if (string.IsNullOrWhiteSpace(targetPath))
        {
            reason = "Path is empty or invalid.";
            return true;
        }

        string full;
        try
        {
            full = Path.GetFullPath(targetPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }
        catch
        {
            reason = "Invalid filesystem syntax.";
            return true;
        }

        // Check Hard Blocked Roots
        foreach (var root in HardBlockedRoots)
        {
            if (string.Equals(full, root, StringComparison.OrdinalIgnoreCase))
            {
                reason = $"Strictly prohibited: System root '{root}' is critical to Windows operation.";
                return true;
            }
        }

        // Prohibit direct root volume drives (e.g. C:\, D:\)
        if (Path.GetPathRoot(full)?.Equals(full + "\\", StringComparison.OrdinalIgnoreCase) == true)
        {
            reason = "Cannot delete root drive volumes.";
            return true;
        }

        // Check user-configured protect list
        lock (LockObj)
        {
            foreach (var protectedPath in UserProtectList)
            {
                if (full.Equals(protectedPath, StringComparison.OrdinalIgnoreCase) ||
                    full.StartsWith(protectedPath + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                {
                    reason = "Protected by user configuration.";
                    return true;
                }
            }
        }

        reason = string.Empty;
        return false;
    }
}
