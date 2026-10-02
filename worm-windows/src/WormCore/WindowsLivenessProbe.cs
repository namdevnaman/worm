using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;

namespace Worm.Core;

/// <summary>
/// Evidence-based liveness checks. Ported from the macOS LivenessProbe.
///
/// These are deliberately soft: a running app's cache can still be cleaned, but
/// the UI warns that some bytes will be recreated. The one exception is an
/// open file handle, which escalates to a block because unlinking a live SQLite
/// or log file sends its owner into an unbounded write loop.
/// </summary>
public static class WindowsLivenessProbe
{
    private const int CacheTtlMs = 3000;
    private static readonly ConcurrentDictionary<string, bool> AppCache = new();
    private static readonly ConcurrentDictionary<string, bool> LockCache = new();
    private static readonly object Gate = new();

    /// <summary>
    /// Maps a cache folder to the executables that own it. Kept deliberately
    /// small and specific: matching a bare vendor name anywhere would produce
    /// constant false positives.
    /// </summary>
    private static readonly (string Marker, string[] Processes)[] Owners =
    {
        (@"\Google\Chrome\User Data",        new[] { "chrome" }),
        (@"\Microsoft\Edge\User Data",       new[] { "msedge" }),
        (@"\BraveSoftware\Brave-Browser",    new[] { "brave" }),
        (@"\Mozilla\Firefox",                new[] { "firefox" }),
        (@"\Opera Software",                 new[] { "opera" }),
        (@"\Vivaldi",                        new[] { "vivaldi" }),
        (@"\Discord",                        new[] { "discord" }),
        (@"\Slack",                          new[] { "slack" }),
        (@"\Spotify",                        new[] { "spotify" }),
        (@"\Code\User",                      new[] { "code" }),
        (@"\Cursor\User",                    new[] { "cursor" }),
        (@"\JetBrains",                      new[] { "idea64", "pycharm64", "webstorm64", "rider64", "goland64", "clion" }),
        (@"\Microsoft\VisualStudio",         new[] { "devenv" }),
        (@"\docker",                         new[] { "docker desktop", "com.docker.backend" }),
        (@"\npm-cache",                      new[] { "node" }),
        (@"\pnpm\store",                     new[] { "node" }),
        (@"\.cargo",                         new[] { "cargo", "rustc" }),
        (@"\pip\cache",                      new[] { "python" }),
        (@"\NuGet",                          new[] { "nuget", "msbuild", "devenv" }),
        (@"\.gradle",                        new[] { "java", "gradle" }),
        (@"\Temp\icue4w",                    new[] { "wps", "word", "excel" }),
    };

    /// <summary>True when a known application that owns this cache is running.</summary>
    public static bool IsUnderLiveApplication(string path)
    {
        var key = path.ToLowerInvariant();
        if (AppCache.TryGetValue(key, out var cached)) return cached;

        lock (Gate)
        {
            if (AppCache.TryGetValue(key, out cached)) return cached;
        }

        var result = false;
        try
        {
            var lower = path.ToLowerInvariant();
            var running = GetRunningProcessNames();

            foreach (var (marker, processes) in Owners)
            {
                if (!lower.Contains(marker, StringComparison.Ordinal)) continue;
                if (processes.Any(p => running.Contains(p))) { result = true; break; }
            }
        }
        catch { }

        AppCache[key] = result;
        _ = Task.Run(async () =>
        {
            await Task.Delay(CacheTtlMs).ConfigureAwait(false);
            AppCache.TryRemove(key, out _);
        });
        return result;
    }

    private static HashSet<string>? _processSnapshot;
    private static DateTime _processSnapshotAt = DateTime.MinValue;

    private static HashSet<string> GetRunningProcessNames()
    {
        lock (Gate)
        {
            // A 2s snapshot is plenty and avoids enumerating every process per row.
            if (_processSnapshot != null && (DateTime.UtcNow - _processSnapshotAt).TotalSeconds < 2)
                return _processSnapshot;

            var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            try
            {
                foreach (var p in Process.GetProcesses())
                {
                    try { set.Add(p.ProcessName); }
                    catch { /* exited or access denied */ }
                    finally { p.Dispose(); }
                }
            }
            catch { }

            _processSnapshot = set;
            _processSnapshotAt = DateTime.UtcNow;
            return set;
        }
    }

    /// <summary>
    /// True when a process holds a handle that would block deletion. Probes the
    /// directory itself and, for a file, an exclusive open.
    /// </summary>
    public static bool IsFileLocked(string path)
    {
        var key = path.ToLowerInvariant();
        if (LockCache.TryGetValue(key, out var cached)) return cached;

        lock (Gate)
        {
            if (LockCache.TryGetValue(key, out cached)) return cached;
        }

        var locked = false;
        try
        {
            if (Directory.Exists(path))
            {
                // A directory that cannot be opened for enumeration is in use.
                try
                {
                    using var e = new DirectoryInfo(path).EnumerateFileSystemInfos().GetEnumerator();
                    e.MoveNext();
                }
                catch (UnauthorizedAccessException) { locked = true; }
                catch (IOException) { locked = true; }
            }
            else if (File.Exists(path))
            {
                try
                {
                    using var s = new FileStream(path, FileMode.Open, FileAccess.ReadWrite,
                                                 FileShare.None);
                }
                catch (IOException) { locked = true; }
                catch (UnauthorizedAccessException) { locked = true; }
            }
        }
        catch { }

        LockCache[key] = locked;
        _ = Task.Run(async () =>
        {
            await Task.Delay(CacheTtlMs).ConfigureAwait(false);
            LockCache.TryRemove(key, out _);
        });
        return locked;
    }

    /// <summary>Best-effort list of process names holding paths under a prefix.</summary>
    public static IReadOnlyList<string> ProcessesUsing(string prefix)
    {
        var result = new List<string>();
        try
        {
            foreach (var p in Process.GetProcesses())
            {
                try
                {
                    var main = p.MainModule?.FileName;
                    if (!string.IsNullOrEmpty(main) &&
                        main.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                    {
                        result.Add(p.ProcessName);
                    }
                }
                catch { }
                finally { p.Dispose(); }
            }
        }
        catch { }
        return result.Distinct(StringComparer.OrdinalIgnoreCase).ToList();
    }
}
