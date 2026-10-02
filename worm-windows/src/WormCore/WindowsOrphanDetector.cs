using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.Win32;

namespace Worm.Core;

public record OrphanItem(
    string AppName,
    string Path,
    long SizeBytes,
    string Category
);

/// <summary>
/// Scans for uninstalled Windows app leftovers across AppData, LocalAppData, and ProgramData
/// by cross-referencing installed software recorded in Windows Registry uninstall keys.
/// </summary>
public static class WindowsOrphanDetector
{
    private static readonly HashSet<string> KnownSystemPublishers = new(StringComparer.OrdinalIgnoreCase)
    {
        "Microsoft", "Windows", "Common Files", "System", "Temp", "Packages", 
        "OEM", "Intel", "NVIDIA", "AMD", "Realtek", "Worm"
    };

    public static IReadOnlyList<OrphanItem> DetectOrphans()
    {
        var installedApps = GetInstalledAppNames();
        var orphans = new List<OrphanItem>();

        var candidateFolders = new[]
        {
            WindowsPaths.LocalAppData,
            WindowsPaths.AppData
        };

        foreach (var root in candidateFolders)
        {
            if (!Directory.Exists(root)) continue;

            try
            {
                var subDirs = Directory.GetDirectories(root);
                foreach (var dir in subDirs)
                {
                    var dirName = Path.GetFileName(dir);
                    if (string.IsNullOrEmpty(dirName) || KnownSystemPublishers.Contains(dirName))
                        continue;

                    // If folder does not match any currently installed application
                    bool matchesInstalled = installedApps.Any(app =>
                        app.Contains(dirName, StringComparison.OrdinalIgnoreCase) ||
                        dirName.Contains(app, StringComparison.OrdinalIgnoreCase));

                    if (!matchesInstalled)
                    {
                        long size = 0;
                        try
                        {
                            var di = new DirectoryInfo(dir);
                            size = di.EnumerateFiles("*", SearchOption.AllDirectories).Sum(f => f.Length);
                        }
                        catch { }

                        if (size > 0)
                        {
                            orphans.Add(new OrphanItem(dirName, dir, size, "Uninstalled App Leftover"));
                        }
                    }
                }
            }
            catch { }
        }

        return orphans;
    }

    private static HashSet<string> GetInstalledAppNames()
    {
        var names = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var keys = new[]
        {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        };

        foreach (var rootKey in new[] { Registry.CurrentUser, Registry.LocalMachine })
        {
            foreach (var subKeyPath in keys)
            {
                try
                {
                    using var key = rootKey.OpenSubKey(subKeyPath);
                    if (key == null) continue;

                    foreach (var subKeyName in key.GetSubKeyNames())
                    {
                        using var appKey = key.OpenSubKey(subKeyName);
                        var displayName = appKey?.GetValue("DisplayName") as string;
                        if (!string.IsNullOrWhiteSpace(displayName))
                        {
                            names.Add(displayName.Trim());
                        }
                    }
                }
                catch { }
            }
        }

        return names;
    }
}
