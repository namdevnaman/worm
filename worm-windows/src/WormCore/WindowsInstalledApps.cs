using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace Worm.Core;

public sealed record InstalledApp(
    string Id,
    string Name,
    string Publisher,
    string Version,
    string InstallLocation,
    string UninstallString,
    string QuietUninstallString,
    long SizeBytes,
    bool IsProtected,
    string ProtectionReason,
    bool IsRunning,
    DateTime? InstallDate
)
{
    public string FormattedSize => WormFormat.Bytes(SizeBytes);

    /// <summary>True when this app still owns its install directory.</summary>
    public bool LooksInstalled =>
        !string.IsNullOrWhiteSpace(InstallLocation) && Directory.Exists(InstallLocation);
}

/// <summary>
/// Installed application enumeration and removal, the Windows analogue of the
/// macOS InstalledApps / AppsView pair.
///
/// Enumeration reads the standard uninstall registry keys under both HKLM and
/// HKCU. That is the only authoritative list Windows exposes, and it is the same
/// list Programs and Features uses, so what Worm shows matches what the user
/// already recognises.
/// </summary>
public static class WindowsInstalledApps
{
    private const string SystemComponentMarker = "SystemComponent";
    private const string ParentKeyMarker = "ParentKeyName";
    private const string WindowsInstaller = "WindowsInstaller";

    private static readonly string[] UninstallRoots =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    };

    private static readonly string[] HkcuUninstallRoots =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    };

    /// <summary>
    /// Apps Worm refuses to remove, with the reason shown in the UI. Being
    /// conservative here matters: removing a component of Windows is not
    /// recoverable from the Recycle Bin.
    /// </summary>
    private static readonly (string Match, string Reason)[] ProtectedPublishers =
    {
        ("Microsoft Corporation", "Part of Windows"),
        ("Microsoft Windows", "Part of Windows"),
    };

    private static readonly string[] ProtectedNameFragments =
    {
        "Visual Studio", "Windows SDK", "Windows Driver Kit", ".NET Runtime",
        ".NET Desktop Runtime", "ASP.NET Core Runtime", "Windows App SDK",
        "Microsoft Edge", "Microsoft Office", "Windows Security",
    };

    /// <summary>
    /// Enumerates registered apps.
    ///
    /// <paramref name="measureSizes"/> defaults to FALSE on purpose. Measuring an
    /// install directory walks thousands of entries, and this method is called
    /// once per vendor folder by the orphan detector, which turned a scan into
    /// hundreds of full directory walks that never finished. Callers that want
    /// sizes ask for them explicitly.
    /// </summary>
    public static IReadOnlyList<InstalledApp> Enumerate(bool probeRunning = true, bool measureSizes = false)
    {
        var apps = new List<InstalledApp>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var hive in new[] { RegistryHive.LocalMachine, RegistryHive.CurrentUser })
        {
            var roots = hive == RegistryHive.CurrentUser ? HkcuUninstallRoots : UninstallRoots;

            foreach (var root in roots)
            {
                try
                {
                    using var baseKey = RegistryKey.OpenBaseKey(hive, RegistryView.Registry64);
                    using var key = baseKey.OpenSubKey(root);
                    if (key == null) continue;

                    foreach (var subName in key.GetSubKeyNames())
                    {
                        try
                        {
                            using var sub = key.OpenSubKey(subName);
                            if (sub == null) continue;

                            var app = ReadEntry(sub, subName, probeRunning, measureSizes);
                            if (app == null) continue;

                            // Deduplicate on the identity the user recognises.
                            var identity = string.IsNullOrWhiteSpace(app.Id) ? app.Name : app.Id;
                            if (!seen.Add(identity)) continue;

                            apps.Add(app);
                        }
                        catch { /* unreadable entry */ }
                    }
                }
                catch { }
            }
        }

        return apps;
    }

    private static InstalledApp? ReadEntry(RegistryKey sub, string subName, bool probeRunning, bool measureSizes)
    {
        var displayName = sub.GetValue("DisplayName") as string;
        if (string.IsNullOrWhiteSpace(displayName)) return null;

        // System components and update hotfixes are not user-facing apps.
        if (sub.GetValue(SystemComponentMarker) is int sysComp && sysComp == 1) return null;
        if (sub.GetValue(ParentKeyMarker) is string parent && !string.IsNullOrWhiteSpace(parent)) return null;

        // A hotfix entry has no DisplayVersion worth showing and a KB name.
        if (displayName.StartsWith("Update for", StringComparison.OrdinalIgnoreCase) &&
            sub.GetValue("KBArticleIDs") != null) return null;

        var publisher = sub.GetValue("Publisher") as string ?? string.Empty;
        var version = sub.GetValue("DisplayVersion") as string ?? string.Empty;
        var installLocation = CleanPath(sub.GetValue("InstallLocation") as string);
        var uninstall = CleanPath(sub.GetValue("UninstallString") as string);
        var quietUninstall = CleanPath(sub.GetValue("QuietUninstallString") as string);

        var id = sub.GetValue("PSChildName") as string ?? subName;

        var (isProtected, reason) = AssessProtection(displayName, publisher, id, installLocation);
        var running = probeRunning && IsRunning(displayName, id);

        DateTime? installDate = null;
        if (sub.GetValue("InstallDate") is string raw && raw.Length == 8 &&
            DateTime.TryParseExact(raw, "yyyyMMdd", System.Globalization.CultureInfo.InvariantCulture,
                                   System.Globalization.DateTimeStyles.None, out DateTime parsed))
        {
            installDate = parsed;
        }

        long size = 0;
        if (measureSizes &&
            !string.IsNullOrEmpty(installLocation) &&
            Directory.Exists(installLocation))
        {
            size = MeasureDirectoryShallow(installLocation);
        }

        return new InstalledApp(
            id, displayName.Trim(), publisher.Trim(), version,
            installLocation ?? string.Empty, uninstall ?? string.Empty, quietUninstall ?? string.Empty,
            size, isProtected, reason, running, installDate);
    }

    private static string? CleanPath(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var value = raw.Trim().Trim('"');

        // Some entries embed a command line; keep only the leading quoted or
        // unquoted path token.
        if (value.Contains('"'))
        {
            var close = value.IndexOf('"', 1);
            if (close > 1) value = value[1..close];
        }
        else
        {
            var exe = value.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
            if (exe > 0)
            {
                var head = value[..(exe + 4)];
                if (head.Contains(' ')) value = head.Trim();
            }
        }

        value = value.Trim();
        return string.IsNullOrEmpty(value) ? null : value;
    }

    private static (bool Protected, string Reason) AssessProtection(
        string name, string publisher, string id, string? installLocation)
    {
        foreach (var (match, reason) in ProtectedPublishers)
        {
            if (publisher.Equals(match, StringComparison.OrdinalIgnoreCase))
                return (true, reason);
        }

        foreach (var fragment in ProtectedNameFragments)
        {
            if (name.Contains(fragment, StringComparison.OrdinalIgnoreCase))
                return (true, "Part of the development toolchain");
        }

        // Never offer to remove the runtime Worm itself depends on.
        if (publisher.Contains("Microsoft", StringComparison.OrdinalIgnoreCase) &&
            (name.Contains("Runtime", StringComparison.OrdinalIgnoreCase) ||
             name.Contains("SDK", StringComparison.OrdinalIgnoreCase)))
        {
            return (true, "Developer toolchain");
        }

        if (installLocation != null &&
            WindowsSafetyPolicy.IsUnder(installLocation, WindowsPaths.ProgramFiles) &&
            publisher.Contains("Microsoft", StringComparison.OrdinalIgnoreCase))
        {
            return (true, "Part of Windows");
        }

        return (false, string.Empty);
    }

    private static readonly Dictionary<string, HashSet<string>> _runningCache =
        new(StringComparer.OrdinalIgnoreCase);
    private static readonly object RunGate = new();
    private static DateTime _runningAt = DateTime.MinValue;

    private static bool IsRunning(string name, string id)
    {
        lock (RunGate)
        {
            if (DateTime.UtcNow - _runningAt > TimeSpan.FromSeconds(5))
            {
                _runningCache.Clear();
                try
                {
                    // ProcessName only. Reading MainModule throws for a large
                    // number of system processes and costs far more than the name,
                    // which is all the match needs.
                    foreach (var p in Process.GetProcesses())
                    {
                        try
                        {
                            var procName = p.ProcessName;
                            if (string.IsNullOrEmpty(procName)) continue;

                            if (!_runningCache.TryGetValue(procName, out var set))
                            {
                                set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
                                _runningCache[procName] = set;
                            }
                            set.Add(procName);
                        }
                        catch { /* exited or access denied */ }
                        finally { p.Dispose(); }
                    }
                }
                catch { }
                _runningAt = DateTime.UtcNow;
            }
        }

        foreach (var (stem, names) in _runningCache)
        {
            if (names.Contains(id) || names.Contains(name)) return true;
            if (id.Contains(stem, StringComparison.OrdinalIgnoreCase) &&
                stem.Length > 3) return true;
        }

        return false;
    }

    /// <summary>
    /// Shallow size measurement: sums top-level files and recurses a bounded
    /// number of levels. A full walk of Program Files is far too slow to do
    /// synchronously while the Apps list is rendering.
    /// </summary>
    private static long MeasureDirectoryShallow(string path, int maxDepth = 2)
    {
        long total = 0;
        var stack = new Stack<(string Path, int Depth)>();
        stack.Push((path, 0));
        int visited = 0;

        while (stack.Count > 0 && visited < 4000)
        {
            var (dir, d) = stack.Pop();
            visited++;

            try
            {
                foreach (var file in Directory.GetFiles(dir))
                {
                    try { total += new FileInfo(file).Length; } catch { }
                }

                if (d >= maxDepth) continue;

                foreach (var sub in Directory.GetDirectories(dir))
                {
                    try
                    {
                        if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push((sub, d + 1));
                    }
                    catch { }
                }
            }
            catch { }
        }

        return total;
    }

    /// <summary>
    /// Removes an app by running its registered uninstaller, preferring the quiet
    /// command when one exists. Deliberately does not attempt a hand-rolled file
    /// delete: silently removing files that a vendor installer owns leaves a
    /// half-uninstalled app, which is worse than a refusal.
    /// </summary>
    public static async Task<RemovalResult> RemoveAsync(InstalledApp app, bool useQuiet = true)
    {
        if (app.IsProtected)
            return RemovalResult.Refused(app.ProtectionReason);

        if (app.IsRunning)
            return RemovalResult.Refused("The app is running. Quit it and try again.");

        var command = useQuiet && !string.IsNullOrWhiteSpace(app.QuietUninstallString)
            ? app.QuietUninstallString
            : app.UninstallString;

        if (string.IsNullOrWhiteSpace(command))
            return RemovalResult.Refused("No uninstall command is registered for this app.");

        try
        {
            var (exe, args) = Split(command);

            var psi = new ProcessStartInfo
            {
                FileName = exe,
                Arguments = args,
                UseShellExecute = true
            };

            using var process = Process.Start(psi);
            if (process == null) return RemovalResult.Refused("The uninstaller did not start.");

            await Task.Run(() => process.WaitForExit(10 * 60 * 1000)).ConfigureAwait(false);

            WindowsAuditLog.Record("OK", app.SizeBytes, app.Name, "Uninstall invoked");
            return RemovalResult.Succeeded(app.Name);
        }
        catch (Exception ex)
        {
            WindowsAuditLog.Record("FAILED", 0, app.Name, ex.Message);
            return RemovalResult.Failed(app.Name, ex.Message);
        }
    }

    private static (string Exe, string Args) Split(string command)
    {
        command = command.Trim();

        if (command.StartsWith('"'))
        {
            var close = command.IndexOf('"', 1);
            if (close > 1)
                return (command[1..close], command[(close + 1)..].Trim());
        }

        var exeEnd = command.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
        if (exeEnd > 0)
        {
            var split = exeEnd + 4;
            return (command[..split], command[split..].Trim());
        }

        var space = command.IndexOf(' ');
        return space < 0 ? (command, string.Empty) : (command[..space], command[(space + 1)..].Trim());
    }

    public readonly record struct RemovalResult(bool Success, bool WasRefused, string Message)
    {
        public static RemovalResult Succeeded(string name) => new(true, false, $"{name} was removed.");
        public static RemovalResult Refused(string reason) => new(false, true, reason);
        public static RemovalResult Failed(string name, string error) => new(false, false, $"{name}: {error}");
    }
}
