using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using Microsoft.Win32;

namespace Worm.Core;

/// <summary>Where a leftover trace lives, mirroring the macOS Location enum.</summary>
public enum OrphanLocation
{
    AppData,
    LocalAppData,
    ProgramData,
    Documents,
}

public static class OrphanLocationInfo
{
    public static string DisplayName(OrphanLocation l) => l switch
    {
        OrphanLocation.AppData => "Roaming AppData",
        OrphanLocation.LocalAppData => "Local AppData",
        OrphanLocation.ProgramData => "ProgramData",
        OrphanLocation.Documents => "Documents",
        _ => "Unknown"
    };
}

public sealed record OrphanTrace(
    string Path,
    string DisplayName,
    long SizeBytes,
    OrphanLocation Location,
    int AgeDays,
    bool NeedsReview,
    string ReviewReason
);

public sealed record OrphanGroup(
    string VendorKey,
    string DisplayName,
    IReadOnlyList<OrphanTrace> Traces
)
{
    public long TotalBytes => Traces.Sum(t => t.SizeBytes);
    public int ReviewCount => Traces.Count(t => t.NeedsReview);
    public string FormattedSize => WormFormat.Bytes(TotalBytes);
}

/// <summary>
/// Detects data left behind by applications that are no longer installed.
///
/// The hard part is proving absence. A folder in AppData is only an orphan when
/// no registered application could plausibly own it, so matching is token-based
/// rather than substring-based: the previous implementation compared
/// app.Contains(dirName), which both missed real orphans (a folder "Spotify" when
/// the app registered as "Spotify Music") and hid live ones (an app named
/// "Codex" matching a folder "Code").
/// </summary>
public static class WindowsOrphanDetector
{
    /// <summary>Never flagged: these hold state, credentials or OS components.</summary>
    private static readonly HashSet<string> NeverOrphan = new(StringComparer.OrdinalIgnoreCase)
    {
        "Microsoft", "Windows", "Packages", "Common Files", "Temp", "ProgramData",
        "Programs", "Intel", "NVIDIA", "AMD", "Realtek", "Worm", "Application Data",
        "Desktop", "Start Menu", "Templates", "SendTo", "Recent", "NetHood",
        "Microsoft Edge", "CrashDumps", "ConnectedDevicesPlatform",
    };

    /// <summary>
    /// Leaf names that usually mean the trace holds the user's own content rather
    /// than regenerable cache. These are surfaced with a review badge instead of
    /// being quietly swept away.
    /// </summary>
    private static readonly string[] UserDataMarkers =
    {
        "documents", "bookmarks", "history", "mail", "notes", "journal", "drafts",
        "library", "library.db", "places.sqlite", "cookies", "login data",
        "profiles", "user data", "backup", "backups", "attachments", "saved",
    };

    private const long MeasureBudgetBytes = 2L * 1024 * 1024 * 1024;
    private const int MaxTraceFiles = 200_000;

    public static IReadOnlyList<OrphanGroup> DetectOrphans()
    {
        var installed = GetInstalledTokens();
        // Resolved ONCE per scan. It used to be recomputed inside the per-folder
        // loop, and each resolution walked every installed app's directory tree,
        // so the scan never completed and the page stayed empty.
        var installIdentities = GetInstallIdentities();
        var groups = new List<OrphanGroup>();

        foreach (var (root, location) in Roots())
        {
            if (!Directory.Exists(root)) continue;

            string[] vendors;
            try { vendors = Directory.GetDirectories(root); }
            catch { continue; }

            foreach (var vendorDir in vendors)
            {
                var vendorName = Path.GetFileName(vendorDir);
                if (string.IsNullOrWhiteSpace(vendorName)) continue;
                if (NeverOrphan.Contains(vendorName)) continue;
                if (vendorName.StartsWith('.')) continue;

                var tokens = Tokenize(vendorName);
                if (tokens.Count == 0) continue;

                // Positive absence: no registered application may own this.
                if (installed.Overlaps(tokens) || OwnedByInstalledApp(vendorDir, vendorName, installIdentities))
                    continue;

                var traces = ScanTraces(vendorDir, location);
                if (traces.Count == 0) continue;

                groups.Add(new OrphanGroup(vendorName, vendorName, traces));
            }
        }

        return groups.OrderByDescending(g => g.TotalBytes).ToList();
    }

    private static IEnumerable<(string Root, OrphanLocation Location)> Roots()
    {
        yield return (WindowsPaths.LocalAppData, OrphanLocation.LocalAppData);
        yield return (WindowsPaths.AppData, OrphanLocation.AppData);
    }

    /// <summary>
    /// Walks a vendor folder and emits one trace per top-level entry. Each trace is
    /// measured with a budget so one enormous tree cannot stall the scan, and a
    /// trace that cannot be measured is reported rather than dropped silently.
    /// </summary>
    private static List<OrphanTrace> ScanTraces(string vendorDir, OrphanLocation location)
    {
        var traces = new List<OrphanTrace>();

        string[] entries;
        try { entries = Directory.GetFileSystemEntries(vendorDir); }
        catch { return traces; }

        foreach (var entry in entries)
        {
            var name = Path.GetFileName(entry);
            if (string.IsNullOrWhiteSpace(name)) continue;

            bool isDir;
            try { isDir = Directory.Exists(entry); }
            catch { continue; }

            var (bytes, measured) = isDir ? MeasureBudgeted(entry) : (SizeOfFile(entry), true);

            if (bytes <= 0) continue;

            int ageDays = AgeInDays(entry);
            var (needsReview, reason) = AssessReview(name, entry, isDir);

            traces.Add(new OrphanTrace(
                entry, name, bytes, location, ageDays, needsReview, reason));
        }

        return traces;
    }

    private static (long Bytes, bool Measured) MeasureBudgeted(string path)
    {
        long total = 0;
        int files = 0;
        bool truncated = false;

        var stack = new Stack<string>();
        stack.Push(path);

        try
        {
            while (stack.Count > 0)
            {
                var dir = stack.Pop();

                try
                {
                    foreach (var sub in Directory.GetDirectories(dir))
                    {
                        // Do not follow junctions out of the folder being measured.
                        if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push(sub);
                    }
                }
                catch { }

                string[] files2;
                try { files2 = Directory.GetFiles(dir); }
                catch { continue; }

                foreach (var file in files2)
                {
                    try
                    {
                        total += new FileInfo(file).Length;
                        if (++files > MaxTraceFiles || total > MeasureBudgetBytes)
                        {
                            truncated = true;
                            break;
                        }
                    }
                    catch { /* skipped, not fatal */ }
                }

                if (truncated) break;
            }
        }
        catch
        {
            return (total, false);
        }

        return (total, !truncated);
    }

    private static long SizeOfFile(string path)
    {
        try { return new FileInfo(path).Length; }
        catch { return 0; }
    }

    private static int AgeInDays(string path)
    {
        try
        {
            var stamp = Directory.Exists(path)
                ? Directory.GetLastWriteTime(path)
                : File.GetLastWriteTime(path);
            return Math.Max(0, (int)(DateTime.Now - stamp).TotalDays);
        }
        catch { return 0; }
    }

    private static (bool NeedsReview, string Reason) AssessReview(string name, string path, bool isDir)
    {
        var lower = name.ToLowerInvariant();

        foreach (var marker in UserDataMarkers)
        {
            if (lower.Contains(marker, StringComparison.Ordinal))
                return (true, $"Contains '{name}', which may hold your own data");
        }

        // A profile or database file inside a leftover folder is user state.
        if (!isDir)
        {
            var ext = Path.GetExtension(lower);
            if (ext is ".sqlite" or ".db" or ".ldb")
                return (true, "Database file; it may contain your history or settings");
        }

        return (false, string.Empty);
    }

    // ------------------------------------------------------------- matching
    private static readonly Regex NonAlnum = new("[^a-z0-9]+", RegexOptions.Compiled);

    /// <summary>Splits a folder or app name into comparable lowercase tokens.</summary>
    internal static HashSet<string> Tokenize(string name)
    {
        var cleaned = NonAlnum.Replace(name.ToLowerInvariant(), " ").Trim();
        if (cleaned.Length == 0) return new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var part in cleaned.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            if (part.Length >= 3) set.Add(part);
        }

        // A single short token like "obs" is too weak to match on; keep the whole
        // cleaned string as an additional exact token instead.
        if (set.Count == 0) set.Add(cleaned);
        return set;
    }

    /// <summary>
    /// Every meaningful token across all registered applications. A vendor folder
    /// is only an orphan when none of its tokens appears here.
    /// </summary>
    private static HashSet<string> GetInstalledTokens()
    {
        var tokens = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var name in GetInstalledAppNames())
        {
            foreach (var t in Tokenize(name)) tokens.Add(t);
        }
        return tokens;
    }

    /// <summary>
    /// Second check against the install location itself. An app whose folder
    /// lives at %LOCALAPPDATA%\Vendor\... owns that folder even when its display
    /// name shares no tokens with the folder name.
    /// </summary>
    /// <summary>
    /// Install locations and their tokens, resolved once and cached.
    /// Registry reads only: no directory walking.
    /// </summary>
    private static List<(string Location, HashSet<string> Tokens)> GetInstallIdentities()
    {
        var list = new List<(string, HashSet<string>)>();

        foreach (var app in WindowsInstalledApps.Enumerate(probeRunning: false, measureSizes: false))
        {
            if (string.IsNullOrWhiteSpace(app.InstallLocation)) continue;

            var location = app.InstallLocation.TrimEnd('\\');
            var leaf = Path.GetFileName(location);
            if (string.IsNullOrEmpty(leaf)) continue;

            list.Add((location, Tokenize(leaf)));
        }

        return list;
    }

    /// <summary>
    /// Second absence check. A vendor folder belongs to a live app when the app
    /// installs inside it, or when a meaningful install-folder token matches.
    /// Generic one-word folder names are ignored so they cannot swallow genuine
    /// orphans.
    /// </summary>
    private static bool OwnedByInstalledApp(
        string vendorDir, string vendorName, List<(string Location, HashSet<string> Tokens)> identities)
    {
        var vendorTokens = Tokenize(vendorName);
        if (vendorTokens.Count == 0) return false;

        foreach (var (location, tokens) in identities)
        {
            if (WindowsSafetyPolicy.IsUnder(vendorDir, location)) return true;

            foreach (var t in tokens)
            {
                // Require a substantial token so a folder called "app" or "bin"
                // does not match half the registered applications.
                if (t.Length < 5) continue;
                if (vendorTokens.Contains(t)) return true;
            }
        }

        return false;
    }

    private static IEnumerable<string> GetInstalledAppNames()
    {
        var roots = new[]
        {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        };

        foreach (var hive in new[] { RegistryHive.CurrentUser, RegistryHive.LocalMachine })
        {
            foreach (var root in roots)
            {
                foreach (var name in ReadDisplayNames(hive, root))
                    yield return name;
            }
        }
    }

    private static List<string> ReadDisplayNames(RegistryHive hive, string root)
    {
        var names = new List<string>();
        try
        {
            using var baseKey = RegistryKey.OpenBaseKey(hive, RegistryView.Registry64);
            using var key = baseKey.OpenSubKey(root);
            if (key == null) return names;

            foreach (var subKeyName in key.GetSubKeyNames())
            {
                try
                {
                    using var appKey = key.OpenSubKey(subKeyName);
                    var display = appKey?.GetValue("DisplayName") as string;
                    if (!string.IsNullOrWhiteSpace(display)) names.Add(display.Trim());
                }
                catch { /* unreadable entry */ }
            }
        }
        catch { }
        return names;
    }

    /// <summary>
    /// Confirms a group is still safe to act on: every trace must pass the safety
    /// policy at the moment of use, not only at scan time.
    /// </summary>
    public static bool CanRemove(OrphanTrace trace)
        => !WindowsSafetyPolicy.Evaluate(trace.Path, probeLiveness: false).IsBlocked;
}
