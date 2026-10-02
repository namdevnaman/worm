using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace Worm.Core;

public record ScanItemResult(
    CleanRule Rule,
    string Path,
    long SizeBytes,
    int FileCount,
    bool IsBlocked,
    string BlockReason
);

public record ScanSummary(
    IReadOnlyList<ScanItemResult> Items,
    long TotalCleanableBytes,
    long TotalBlockedBytes
);

/// <summary>
/// Asynchronous multi-threaded filesystem scanner.
/// Evaluates directory sizes, file counts, and checks every target against the safety policy.
/// </summary>
public static class WindowsScanner
{
    public static async Task<ScanSummary> RunScanAsync(IProgress<(string currentTask, double percent)>? progress = null, CancellationToken ct = default)
    {
        var rules = WindowsScanCatalog.GetRules();
        var results = new List<ScanItemResult>();
        long totalCleanable = 0;
        long totalBlocked = 0;

        for (int i = 0; i < rules.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var rule = rules[i];
            progress?.Report((rule.Name, (double)i / rules.Count * 100.0));

            var targetPath = WindowsPaths.Expand(rule.PathExpression);
            if (!Directory.Exists(targetPath) && !File.Exists(targetPath))
                continue;

            bool isBlocked = WindowsSafetyPolicy.IsPathProtected(targetPath, out string reason);

            long size = 0;
            int count = 0;

            await Task.Run(() =>
            {
                try
                {
                    if (File.Exists(targetPath))
                    {
                        var fi = new FileInfo(targetPath);
                        size = fi.Length;
                        count = 1;
                    }
                    else if (Directory.Exists(targetPath))
                    {
                        var di = new DirectoryInfo(targetPath);
                        foreach (var fi in di.EnumerateFiles(rule.SearchPattern, SearchOption.AllDirectories))
                        {
                            if (ct.IsCancellationRequested) break;
                            try
                            {
                                size += fi.Length;
                                count++;
                            }
                            catch { }
                        }
                    }
                }
                catch { }
            }, ct);

            if (count > 0 || size > 0)
            {
                var item = new ScanItemResult(rule, targetPath, size, count, isBlocked, reason);
                results.Add(item);

                if (isBlocked) totalBlocked += size;
                else totalCleanable += size;
            }
        }

        progress?.Report(("Scan Complete", 100.0));
        return new ScanSummary(results, totalCleanable, totalBlocked);
    }
}
