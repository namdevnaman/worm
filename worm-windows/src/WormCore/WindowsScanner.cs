using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Worm.Core;

public record ScanItemResult(
    CleanRule Rule,
    string Path,
    long SizeBytes,
    int FileCount,
    bool IsMeasurable,
    bool IsBlocked,
    string BlockReason,
    SafetyReason BlockReasonCode,
    SafetyVerdict Verdict,
    string Label
)
{
    public string FormattedSize => IsMeasurable
        ? FormatBytes(SizeBytes)
        : "needs access";

    public string StatusText => IsBlocked
        ? SafetyVerdict.Title(BlockReasonCode)
        : Verdict.HasWarning
            ? SafetyVerdict.Title(Verdict.Reason)
            : "Cleanable";

    private static string FormatBytes(long bytes)
    {
        string[] suffix = { "B", "KB", "MB", "GB", "TB" };
        int counter = 0;
        double number = bytes;
        while (Math.Round(number / 1024) >= 1 && counter < suffix.Length - 1)
        {
            number /= 1024;
            counter++;
        }
        return $"{number:n1} {suffix[counter]}";
    }
}

public record ScanSummary(
    IReadOnlyList<ScanItemResult> Items,
    long TotalCleanableBytes,
    long TotalBlockedBytes,
    IReadOnlyDictionary<string, long> ByCategory
);

/// <summary>
/// Walks the catalog, measures each target, and evaluates the safety policy.
/// Runs every filesystem walk on the thread pool so the UI never blocks.
/// </summary>
public static class WindowsScanner
{
    public static async Task<ScanSummary> RunScanAsync(
        IProgress<(string CurrentTask, double Percent)>? progress = null,
        CancellationToken ct = default,
        bool probeLiveness = true)
    {
        var rules = WindowsScanCatalog.GetRules();
        var results = new List<ScanItemResult>();
        long totalCleanable = 0;
        long totalBlocked = 0;
        var byCategory = new Dictionary<string, long>(StringComparer.Ordinal);

        for (int i = 0; i < rules.Count; i++)
        {
            ct.ThrowIfCancellationRequested();
            var rule = rules[i];
            progress?.Report((rule.Name, (double)i / rules.Count * 100.0));

            var targets = await Task.Run(() => WindowsScanCatalog.ExpandTargets(rule).ToList(), ct)
                               .ConfigureAwait(true);

            foreach (var target in targets)
            {
                ct.ThrowIfCancellationRequested();

                if (!WindowsScanCatalog.PassesAge(target, rule.MinAgeDays)) continue;

                // Duplicate targets are normal: a glob and an explicit rule can
                // resolve to the same folder. Collapse on the normalised path.
                var key = WindowsSafetyPolicy.Normalize(target);
                if (results.Any(r => string.Equals(WindowsSafetyPolicy.Normalize(r.Path), key,
                        StringComparison.OrdinalIgnoreCase)))
                {
                    continue;
                }

                var verdict = WindowsSafetyPolicy.Evaluate(target, probeLiveness);

                var (size, count, measurable) = await Task.Run(() => Measure(target), ct)
                                                       .ConfigureAwait(true);

                var blocked = verdict.IsBlocked;
                var item = new ScanItemResult(
                    rule, target, size, count, measurable, blocked,
                    blocked ? SafetyVerdict.Detail(verdict.Reason) : string.Empty,
                    verdict.Reason, verdict, Describe(rule, target));

                results.Add(item);

                if (blocked) totalBlocked += size;
                else totalCleanable += size;

                byCategory.TryGetValue(rule.Category, out var running);
                byCategory[rule.Category] = running + (blocked ? 0 : size);
            }
        }

        progress?.Report(("Scan complete", 100.0));

        return new ScanSummary(
            results.OrderByDescending(r => r.IsBlocked).ThenByDescending(r => r.SizeBytes).ToList(),
            totalCleanable, totalBlocked, byCategory);
    }

    /// <summary>Category rollup, including blocked totals, for the sidebar.</summary>
    public static async Task<IReadOnlyDictionary<string, CategoryRollup>> RollUpAsync(
        CancellationToken ct = default, bool probeLiveness = true)
    {
        var summary = await RunScanAsync(null, ct, probeLiveness).ConfigureAwait(false);

        var rollup = new Dictionary<string, CategoryRollup>(StringComparer.Ordinal);
        foreach (var category in WindowsScanCatalog.Categories)
        {
            rollup[category] = new CategoryRollup(category);
        }

        foreach (var item in summary.Items)
        {
            if (!rollup.TryGetValue(item.Rule.Category, out var entry))
            {
                entry = new CategoryRollup(item.Rule.Category);
                rollup[item.Rule.Category] = entry;
            }
            entry.Add(item);
        }

        return rollup;
    }

    private static string Describe(CleanRule rule, string target)
    {
        var name = Path.GetFileName(target.TrimEnd(Path.DirectorySeparatorChar));
        if (string.IsNullOrEmpty(name)) name = rule.Name;
        return name;
    }

    /// <summary>
    /// Allocates a byte budget so one pathological tree cannot stall a scan.
    /// Returns measurable=false when the budget runs out, which the UI shows as
    /// "needs access" rather than a misleading number.
    /// </summary>
    private static (long Size, int Count, bool Measurable) Measure(string path)
    {
        const long BudgetBytes = 2L * 1024 * 1024 * 1024;
        const int BudgetFiles = 400_000;

        long size = 0;
        int count = 0;
        bool truncated = false;

        try
        {
            if (File.Exists(path))
            {
                size = new FileInfo(path).Length;
                count = 1;
                return (size, count, true);
            }

            if (!Directory.Exists(path)) return (0, 0, false);

            // Enumerate iteratively so a deep tree cannot blow the stack.
            var stack = new Stack<string>();
            stack.Push(path);

            while (stack.Count > 0)
            {
                var dir = stack.Pop();
                string[] subs;
                try { subs = Directory.GetDirectories(dir); }
                catch { continue; }

                foreach (var sub in subs)
                {
                    try
                    {
                        // Follow junctions into other volumes would be a surprise;
                        // skip reparse points so measurement stays on one volume.
                        if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                        stack.Push(sub);
                    }
                    catch { }
                }

                string[] files;
                try { files = Directory.GetFiles(dir); }
                catch { continue; }

                foreach (var file in files)
                {
                    try
                    {
                        size += new FileInfo(file).Length;
                        count++;
                        if (size > BudgetBytes || count > BudgetFiles) { truncated = true; break; }
                    }
                    catch { }
                }

                if (truncated) break;
            }
        }
        catch
        {
            return (size, count, false);
        }

        return (size, count, !truncated);
    }
}

public class CategoryRollup
{
    public string Name { get; }
    public long CleanableBytes { get; private set; }
    public long BlockedBytes { get; private set; }
    public int CleanableCount { get; private set; }
    public int BlockedCount { get; private set; }
    public int TotalCount => CleanableCount + BlockedCount;

    public CategoryRollup(string name) => Name = name;

    internal void Add(ScanItemResult item)
    {
        if (item.IsBlocked)
        {
            BlockedBytes += item.SizeBytes;
            BlockedCount++;
        }
        else
        {
            CleanableBytes += item.SizeBytes;
            CleanableCount++;
        }
    }
}
