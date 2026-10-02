using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Worm.Core;

public sealed record VolumeInfo(
    string Name,
    string Label,
    string Format,
    long TotalBytes,
    long FreeBytes,
    bool Ready
)
{
    public long UsedBytes => Math.Max(0, TotalBytes - FreeBytes);
    public double UsedFraction => TotalBytes > 0 ? (double)UsedBytes / TotalBytes : 0;
    public string FormattedTotal => WormFormat.Bytes(TotalBytes);
    public string FormattedUsed => WormFormat.Bytes(UsedBytes);
    public string FormattedFree => WormFormat.Bytes(FreeBytes);

    /// <summary>Health thresholds copied from the macOS gauge.</summary>
    public string GaugeColorKey => UsedFraction switch
    {
        > 0.92 => "Danger",
        > 0.85 => "Warn",
        _ => "Accent"
    };

    public string GaugeNote => UsedFraction switch
    {
        > 0.92 => "Windows needs working space to update and page",
        > 0.85 => "cleaning now keeps Windows responsive",
        _ => "healthy"
    };
}

public sealed record FolderSize(string Path, string Name, long Bytes)
{
    public string FormattedSize => WormFormat.Bytes(Bytes);
}

public sealed record LargeFile(string Path, string Name, long Bytes, DateTime ModifiedUtc)
{
    public string FormattedSize => WormFormat.Bytes(Bytes);
    public string Parent => System.IO.Path.GetDirectoryName(Path) ?? string.Empty;
    public string Age => WormFormat.Age(ModifiedUtc);
}

public sealed record DiskSummary(
    IReadOnlyList<VolumeInfo> Volumes,
    long TotalBytes,
    long FreeBytes,
    long UsedBytes,
    IReadOnlyList<FolderSize> BiggestFolders,
    IReadOnlyList<LargeFile> LargeFiles)
{
    public double UsedFraction => TotalBytes > 0 ? (double)UsedBytes / TotalBytes : 0;
    public string FormattedTotal => WormFormat.Bytes(TotalBytes);
    public string FormattedUsed => WormFormat.Bytes(UsedBytes);
    public string FormattedFree => WormFormat.Bytes(FreeBytes);
    public string PercentUsed => WormFormat.Percent(UsedFraction);

    public string GaugeColorKey => UsedFraction switch
    {
        > 0.92 => "Danger",
        > 0.85 => "Warn",
        _ => "Accent"
    };

    public string GaugeNote => UsedFraction switch
    {
        > 0.92 => "Windows needs working space to update and page",
        > 0.85 => "cleaning now keeps Windows responsive",
        _ => "healthy"
    };
}

/// <summary>
/// The Windows analogue of the macOS DiskView: volume capacity, the biggest
/// folders one level into the profile, and a read-only large-file finder.
///
/// The large-file finder is strictly read-only. It reports; it never deletes, and
/// the UI says so, because a file being large is not evidence that it is junk.
/// </summary>
public static class WindowsDiskAnalyzer
{
    private static readonly string[] LargeFileSkipFolders =
    {
        @"$Recycle.Bin", @"System Volume Information", @"Windows\WinSxS", @"Windows\Installer",
        @"Windows\SoftwareDistribution", @"Program Files\WindowsApps", @"Windows\assembly",
    };

    public static IReadOnlyList<VolumeInfo> Volumes()
    {
        var list = new List<VolumeInfo>();

        foreach (var d in DriveInfo.GetDrives())
        {
            try
            {
                if (!d.IsReady) continue;

                string label;
                try { label = d.VolumeLabel; }
                catch { label = string.Empty; }

                list.Add(new VolumeInfo(
                    d.Name, label, d.DriveFormat,
                    d.TotalSize, d.AvailableFreeSpace, d.IsReady));
            }
            catch { /* unplugged or unreadable volume */ }
        }

        return list;
    }

    public static DiskSummary Measure(
        long largeFileThresholdBytes = 500L * 1024 * 1024,
        int maxFolders = 14,
        int maxFiles = 40)
    {
        var volumes = Volumes();

        long total = 0, free = 0;
        foreach (var v in volumes)
        {
            total += v.TotalBytes;
            free += v.FreeBytes;
        }

        return new DiskSummary(
            volumes, total, free, Math.Max(0, total - free),
            Array.Empty<FolderSize>(), Array.Empty<LargeFile>());
    }

    /// <summary>
    /// Expensive analysis, run off the UI thread. Bounded by a hard deadline so a
    /// slow or enormous tree cannot leave the page spinning indefinitely.
    /// </summary>
    public static async Task<(IReadOnlyList<FolderSize> Folders, IReadOnlyList<LargeFile> Files)> AnalyzeAsync(
        long largeFileThresholdBytes = 500L * 1024 * 1024,
        int maxFolders = 14,
        int maxFiles = 40,
        IProgress<string>? progress = null,
        CancellationToken ct = default)
    {
        return await Task.Run(() =>
        {
            var deadline = DateTime.UtcNow.AddSeconds(20);

            progress?.Report("Measuring home directories…");
            var folders = BiggestFolders(maxFolders, deadline, ct);

            progress?.Report("Searching for large files…");
            var files = FindLargeFiles(largeFileThresholdBytes, maxFiles, deadline, ct);

            return (folders, files);
        }, ct).ConfigureAwait(false);
    }

    private static IReadOnlyList<FolderSize> BiggestFolders(int limit, DateTime deadline, CancellationToken ct)
    {
        var profile = WindowsPaths.UserProfile;
        var results = new List<FolderSize>();

        string[] children;
        try { children = Directory.GetDirectories(profile); }
        catch { return results; }

        foreach (var dir in children)
        {
            if (ct.IsCancellationRequested) break;
            if (DateTime.UtcNow > deadline) break;

            var name = Path.GetFileName(dir);

            // Skip dot-directories except the caches worth surfacing.
            if (name.StartsWith('.') &&
                !name.Equals(".cache", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            var bytes = MeasureWithBudget(dir, deadline, ct);
            if (bytes > 0) results.Add(new FolderSize(dir, name, bytes));
        }

        return results.OrderByDescending(f => f.Bytes).Take(limit).ToList();
    }

    private static IReadOnlyList<LargeFile> FindLargeFiles(
        long threshold, int limit, DateTime deadline, CancellationToken ct)
    {
        var found = new List<LargeFile>();
        var stack = new Stack<string>();
        stack.Push(WindowsPaths.UserProfile);

        int visited = 0;

        while (stack.Count > 0 && found.Count < limit * 4)
        {
            if (ct.IsCancellationRequested) break;
            if (DateTime.UtcNow > deadline) break;
            if (++visited > 60_000) break;

            var dir = stack.Pop();

            // Never descend into caches: those are the Clean tab's job, and
            // counting them twice would make this screen look broken.
            var lower = dir.ToLowerInvariant();
            if (lower.EndsWith(@"\appdata\local\temp", StringComparison.Ordinal) ||
                lower.EndsWith(@"\appdata\local\microsoft\windows\inetcache", StringComparison.Ordinal) ||
                lower.EndsWith(@"\$recycle.bin", StringComparison.Ordinal) ||
                lower.EndsWith(@"\node_modules", StringComparison.Ordinal) ||
                lower.Contains(@"\.git\objects"))
            {
                continue;
            }

            try
            {
                foreach (var file in Directory.GetFiles(dir))
                {
                    try
                    {
                        var info = new FileInfo(file);
                        if (!info.Exists) continue;

                        var name = info.Name;
                        if (name.StartsWith('.')) continue;

                        if (info.Length < threshold) continue;
                        if (name.EndsWith(".zip", StringComparison.OrdinalIgnoreCase) &&
                            info.Length < threshold * 4) { /* keep, still large */ }

                        found.Add(new LargeFile(file, name, info.Length, info.LastWriteTimeUtc));
                    }
                    catch { }
                }

                foreach (var sub in Directory.GetDirectories(dir))
                {
                    try
                    {
                        var attr = File.GetAttributes(sub);
                        if ((attr & FileAttributes.ReparsePoint) != 0) continue;
                        if ((attr & FileAttributes.System) != 0) continue;
                        stack.Push(sub);
                    }
                    catch { }
                }
            }
            catch { }
        }

        return found.OrderByDescending(f => f.Bytes).Take(limit).ToList();
    }

    private static long MeasureWithBudget(string path, DateTime deadline, CancellationToken ct)
    {
        const long Budget = 8L * 1024 * 1024 * 1024;
        long total = 0;
        var stack = new Stack<string>();
        stack.Push(path);
        int visited = 0;

        while (stack.Count > 0)
        {
            if (ct.IsCancellationRequested) break;
            if (DateTime.UtcNow > deadline) break;
            if (++visited > 200_000) break;
            if (total > Budget) break;

            var dir = stack.Pop();
            try
            {
                foreach (var file in Directory.GetFiles(dir))
                {
                    try { total += new FileInfo(file).Length; } catch { }
                }
                foreach (var sub in Directory.GetDirectories(dir))
                {
                    try
                    {
                        if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push(sub);
                    }
                    catch { }
                }
            }
            catch { }
        }

        return total;
    }
}
