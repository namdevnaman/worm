using System;
using System.IO;
using System.Linq;
using Worm.Core;
using Xunit;

namespace Worm.Core.Tests;

/// <summary>
/// Guards the single worst failure mode this app can have.
///
/// An earlier catalog enumerated the direct children of %LOCALAPPDATA% and
/// %APPDATA% as cleanable. Those directories contain Packages, which holds every
/// Microsoft Store and UWP app's data, plus one folder per installed app. The
/// result was that the Clean screen listed installed applications as junk and
/// deleted their data.
///
/// Nothing about that bug throws, logs an error or looks unusual. The app ran,
/// the list populated, and the deletion succeeded. Only a test can catch it.
/// </summary>
public class NoWholesaleAppDataEnumerationTests
{
    private static readonly string[] AppDataRoots =
    {
        WindowsPaths.LocalAppData,
        WindowsPaths.AppData,
        WindowsPaths.ProgramData,
        WindowsPaths.UserProfile,
    };

    [Fact]
    public void NoRuleEnumeratesChildrenOfAnAppDataRoot()
    {
        var offenders = new System.Collections.Generic.List<string>();

        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            // The rule's base must not be an AppData root consumed with Children,
            // which is what marks every vendor folder as a deletion target.
            if (rule.Kind != RuleKind.Children) continue;

            var basePath = WindowsSafetyPolicy.Normalize(rule.PathExpression);

            foreach (var root in AppDataRoots)
            {
                var normalisedRoot = WindowsSafetyPolicy.Normalize(root);
                if (string.IsNullOrEmpty(normalisedRoot)) continue;

                if (WindowsSafetyPolicy.IsUnder(basePath, normalisedRoot))
                {
                    offenders.Add($"{rule.Id} -> Children of {basePath}");
                }
            }
        }

        Assert.True(offenders.Count == 0,
            "These rules enumerate the children of an AppData root, which targets " +
            "Packages and every installed app's own folder:" +
            Environment.NewLine + string.Join(Environment.NewLine, offenders));
    }

    [Fact]
    public void CriticalFoldersAreNotCacheLeaves()
    {
        // A leaf named Temp inside an app folder is legitimate scratch, but these
        // must never be reachable through a CacheLeaves walk.
        foreach (var name in new[] { "Packages", "Microsoft", "Programs", "Windows" })
        {
            Assert.False(
                WindowsScanCatalog.CacheLeafNames.Any(l => l.Contains(name, StringComparison.OrdinalIgnoreCase)),
                $"'{name}' appears in the cache leaf list");
        }
    }

    [Fact]
    public void CacheLeafListContainsOnlyRegenerableArtefacts()
    {
        // Every leaf must look like a cache, not like app state. Anything holding
        // documents, bookmarks or history must never be a deletion target.
        foreach (var banned in new[] { "Documents", "Bookmarks", "History", "Mail",
                                       "Notes", "Profiles", "User Data", "Local Storage" })
        {
            Assert.False(
                WindowsScanCatalog.CacheLeafNames.Any(l => l.Equals(banned, StringComparison.OrdinalIgnoreCase)),
                $"'{banned}' must never be a cache leaf");
        }
    }

    [Fact]
    public void PackagesIsNeverATargetRoot()
    {
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            var p = rule.PathExpression;
            Assert.DoesNotContain("Packages", p, StringComparison.OrdinalIgnoreCase);
        }
    }

    /// <summary>
    /// End-to-end guard: expand the real rules in a synthetic AppData tree and
    /// assert that an installed app's own folder is never returned.
    /// </summary>
    [Fact]
    public void ExpansionNeverReturnsAnInstalledAppsOwnFolder()
    {
        var root = Path.Combine(Path.GetTempPath(),
            "worm-fake-appdata-" + Guid.NewGuid().ToString("N"));

        // Models a real %LOCALAPPDATA%: one installed app folder, one cache leaf.
        var installedApp = Path.Combine(root, "Spotify");
        var itsCache = Path.Combine(installedApp, "Cache");
        Directory.CreateDirectory(itsCache);
        File.WriteAllText(Path.Combine(itsCache, "blob"), "x");

        var rule = new CleanRule(
            "test", "test", "App Caches", "test", RiskLevel.Regenerable,
            root, RuleKind.CacheLeaves);

        try
        {
            var targets = WindowsScanCatalog.ExpandTargets(rule).ToList();

            Assert.DoesNotContain(targets, t =>
                WindowsSafetyPolicy.IsUnder(t, installedApp) &&
                !WindowsSafetyPolicy.IsUnder(t, itsCache));

            Assert.Contains(targets, t =>
                WindowsSafetyPolicy.IsUnder(t, itsCache));
        }
        finally
        {
            try { Directory.Delete(root, true); } catch { }
        }
    }
}
