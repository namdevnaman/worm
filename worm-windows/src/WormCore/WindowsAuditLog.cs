using System;
using System.IO;
using System.Text;

namespace Worm.Core;

/// <summary>
/// Single writer for the local audit log at
/// %LOCALAPPDATA%\Worm\Logs\deletions.tsv. Kept separate from the reclaimer so
/// every destructive action, including ones that never go through a scan rule
/// such as emptying the Recycle Bin, lands in the same permanent record.
/// </summary>
public static class WindowsAuditLog
{
    private static readonly object Gate = new();

    public static string LogDirectory => WindowsPaths.LogDir;
    public static string LogFilePath => WindowsPaths.DeletionLog;

    /// <summary>
    /// Appends one operation. Never throws: losing an audit line must not be the
    /// reason a cleanup fails, and failing cleanup must not lose the audit line.
    /// </summary>
    public static void Record(string status, long bytes, string target, string note)
    {
        try
        {
            var dir = WindowsPaths.LogDir;
            if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);

            var line = string.Join('\t',
                DateTime.UtcNow.ToString("O"),
                status,
                bytes.ToString(),
                target.Replace('\t', ' '),
                (note ?? string.Empty).Replace('\t', ' ').Replace('\n', ' ')) + "\n";

            lock (Gate)
            {
                File.AppendAllText(LogFilePath, line, Encoding.UTF8);
            }
        }
        catch
        {
            // Intentionally silent.
        }
    }

    public readonly record struct Entry(
        DateTime TimestampUtc, string Status, long Bytes, string Target, string Note);

    /// <summary>
    /// Reads back the most recent entries for the Settings view. Tolerates a
    /// truncated final line, which is what a crash mid-write leaves behind.
    /// </summary>
    public static System.Collections.Generic.IReadOnlyList<Entry> Recent(int limit = 200)
    {
        var results = new System.Collections.Generic.List<Entry>();
        try
        {
            if (!File.Exists(LogFilePath)) return results;

            var lines = File.ReadAllLines(LogFilePath);
            var start = Math.Max(0, lines.Length - limit);

            for (int i = start; i < lines.Length; i++)
            {
                var parts = lines[i].Split('\t');
                if (parts.Length < 5) continue;

                if (!DateTime.TryParse(parts[0], out var when)) continue;
                long.TryParse(parts[2], out var bytes);

                results.Add(new Entry(when, parts[1], bytes, parts[3], parts[4]));
            }
        }
        catch { }

        results.Reverse();
        return results;
    }
}
