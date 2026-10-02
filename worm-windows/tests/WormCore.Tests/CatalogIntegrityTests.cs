using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Worm.Core;
using Xunit;

namespace Worm.Core.Tests;

/// <summary>
/// Guards the properties that keep the cleaner safe. These run without needing a
/// real Windows filesystem: they check the shape of the catalog and the policy's
/// matching logic against synthetic paths.
/// </summary>
public class CatalogIntegrityTests
{
    [Fact]
    public void RuleIdsAreUnique()
    {
        var rules = WindowsScanCatalog.GetRules();
        var dupes = rules.GroupBy(r => r.Id, StringComparer.OrdinalIgnoreCase)
                         .Where(g => g.Count() > 1)
                         .Select(g => g.Key)
                         .ToList();
        Assert.True(dupes.Count == 0, $"Duplicate rule ids: {string.Join(", ", dupes)}");
    }

    [Fact]
    public void EveryRuleBelongsToADeclaredCategory()
    {
        var declared = WindowsScanCatalog.Categories.ToHashSet(StringComparer.Ordinal);
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            Assert.True(declared.Contains(rule.Category),
                $"Rule '{rule.Id}' uses undeclared category '{rule.Category}'");
        }
    }

    /// <summary>
    /// Every category is backed either by at least one rule, or is explicitly
    /// declared special (the Recycle Bin has no filesystem path). A category with
    /// neither is dead UI.
    /// </summary>
    [Fact]
    public void EveryCategoryIsRuleBackedOrExplicitlySpecial()
    {
        var used = WindowsScanCatalog.GetRules().Select(r => r.Category).ToHashSet(StringComparer.Ordinal);
        foreach (var category in WindowsScanCatalog.Categories)
        {
            var backed = used.Contains(category);
            var special = WindowsScanCatalog.IsSpecialCategory(category);
            Assert.True(backed || special,
                $"Category '{category}' has no rules and is not declared special");
        }
    }

    [Fact]
    public void EveryDeclaredSpecialCategoryAppearsInTheCategoryList()
    {
        foreach (var category in WindowsScanCatalog.SpecialCategories)
        {
            Assert.Contains(category, WindowsScanCatalog.Categories);
        }
    }

    [Fact]
    public void DefaultCategoryExists()
    {
        Assert.Contains(WindowsScanCatalog.DefaultCategory, WindowsScanCatalog.Categories);
        Assert.NotEmpty(WindowsScanCatalog.RulesFor(WindowsScanCatalog.DefaultCategory));
    }

    /// <summary>
    /// The allowlist is derived from the rules. If it were ever hand-maintained it
    /// would silently drift and start refusing a tool's own cache as "outside a
    /// cleanable folder", which is exactly the bug this design exists to prevent.
    /// </summary>
    [Fact]
    public void CleanableRootsCoverEveryRuleTarget()
    {
        var roots = WindowsScanCatalog.CleanableRoots()
            .Select(Normalize)
            .ToList();

        Assert.NotEmpty(roots);

        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            var target = Normalize(rule.PathExpression);

            if (rule.Kind == RuleKind.Glob)
            {
                // A glob declares its literal parent as the root.
                var parent = Normalize(Path.GetDirectoryName(rule.PathExpression) ?? string.Empty);
                Assert.True(roots.Any(r => WindowsSafetyPolicy.IsUnder(target, r) ||
                                           WindowsSafetyPolicy.IsUnder(parent, r) ||
                                           string.Equals(r, parent, StringComparison.OrdinalIgnoreCase)),
                    $"Glob rule '{rule.Id}' has no cleanable root covering {target}");
                continue;
            }

            Assert.True(roots.Any(r => WindowsSafetyPolicy.IsUnder(target, r) ||
                                       string.Equals(r, target, StringComparison.OrdinalIgnoreCase)),
                $"Rule '{rule.Id}' targets {target} which is outside every cleanable root");
        }
    }

    /// <summary>
    /// Guards the correction of the original catalog bug: Gradle targeted
    /// .gradle\caches wholesale, which swallowed modules-2, a directory the
    /// policy hard-blocks as toolchain state.
    /// </summary>
    [Fact]
    public void NoRuleTargetsGradleModulesDirectly()
    {
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            Assert.DoesNotContain("modules-2", rule.PathExpression, StringComparison.OrdinalIgnoreCase);
            Assert.DoesNotContain("wrapper", rule.PathExpression, StringComparison.OrdinalIgnoreCase);
        }
    }

    /// <summary>Nothing may target a drive root or the user profile itself.</summary>
    [Fact]
    public void NoRuleTargetsADriveRootOrUserProfile()
    {
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            var target = Normalize(rule.PathExpression);
            Assert.False(target.Length <= 3 && target[1] == ':',
                $"Rule '{rule.Id}' targets a drive root: {target}");
            Assert.False(target.Contains("%USERPROFILE%", StringComparison.OrdinalIgnoreCase),
                $"Rule '{rule.Id}' targets the user profile itself");
        }
    }

    [Fact]
    public void EveryRuleHasHumanReadableMetadata()
    {
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            Assert.False(string.IsNullOrWhiteSpace(rule.Name), $"Rule '{rule.Id}' has no name");
            Assert.False(string.IsNullOrWhiteSpace(rule.Description),
                $"Rule '{rule.Id}' has no description");
        }
    }

    [Fact]
    public void UserDataRiskRulesAreMarkedExplicitly()
    {
        // Nothing should be quietly classified as UserData without a reason;
        // this keeps the risk taxonomy honest rather than decorative.
        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            if (rule.Risk == RiskLevel.UserData)
                Assert.False(string.IsNullOrWhiteSpace(rule.Description));
        }
    }

    private static string Normalize(string p)
    {
        var expanded = WindowsPaths.Expand(p);
        return expanded.Length > 3 ? expanded.TrimEnd('\\') : expanded;
    }
}

public class PathMatchingTests
{
    [Theory]
    [InlineData(@"C:\Windows\System32", @"C:\Windows", true)]
    [InlineData(@"C:\Windows\System32\drivers", @"C:\Windows", true)]
    [InlineData(@"C:\Windows\System32\drivers\etc\hosts", @"C:\Windows\System32", true)]
    [InlineData(@"C:\WINDOWS\System32", @"C:\Windows", true)]
    [InlineData(@"C:\Windows.old\thing", @"C:\Windows", false)]
    [InlineData(@"C:\Program Files\App", @"C:\Program Files", true)]
    [InlineData(@"C:\Users\alice\Documents", @"C:\Users\alice", true)]
    public void IsUnderIsPrefixAwareAndCaseInsensitive(string path, string root, bool expected)
    {
        Assert.Equal(expected, WindowsSafetyPolicy.IsUnder(path, root));
    }

    /// <summary>
    /// This is the exact bug in the original policy: it compared blocked roots
    /// with string equality, so "C:\Windows\System32" was protected while
    /// "C:\Windows\System32\drivers" was not.
    /// </summary>
    [Fact]
    public void BlockedRootsAreNotMerelyExactMatches()
    {
        // Exercise the prefix semantics directly, since a real Windows
        // filesystem is not available here.
        Assert.True(WindowsSafetyPolicy.IsUnder(@"C:\Windows\System32\drivers\etc", @"C:\Windows\System32"));
        Assert.False(WindowsSafetyPolicy.IsUnder(@"C:\Windows\System32Backup", @"C:\Windows\System32"));
    }
}

public class SafetyVerdictTests
{
    [Fact]
    public void EmptyPathIsBlocked()
    {
        var verdict = WindowsSafetyPolicy.Evaluate("");
        Assert.True(verdict.IsBlocked);
        Assert.Equal(SafetyReason.PathInvalid, verdict.Reason);
    }

    [Fact]
    public void NullPathIsBlocked()
    {
        var verdict = WindowsSafetyPolicy.Evaluate(null!);
        Assert.True(verdict.IsBlocked);
    }

    [Fact]
    public void EveryReasonHasATitleAndDetail()
    {
        foreach (SafetyReason reason in Enum.GetValues(typeof(SafetyReason)))
        {
            if (reason == SafetyReason.None) continue;
            Assert.False(string.IsNullOrWhiteSpace(SafetyVerdict.Title(reason)),
                $"Reason {reason} has no title");
            Assert.False(string.IsNullOrWhiteSpace(SafetyVerdict.Detail(reason)),
                $"Reason {reason} has no detail");
        }
    }

    [Fact]
    public void AllowWithWarningIsStillAllowed()
    {
        var verdict = new SafetyVerdict(SafetyVerdictKind.AllowWithWarning, SafetyReason.LiveApplicationCache);
        Assert.True(verdict.IsAllowed);
        Assert.False(verdict.IsBlocked);
        Assert.True(verdict.HasWarning);
    }
}

public class UserProtectListTests
{
    [Fact]
    public void ProtectListRoundTrips()
    {
        var original = WindowsSafetyPolicy.GetProtectedPaths().ToList();
        try
        {
            var temp = Path.Combine(Path.GetTempPath(), "worm-protect-test-" + Guid.NewGuid().ToString("N"));
            WindowsSafetyPolicy.AddProtectedPath(temp);

            Assert.Contains(WindowsSafetyPolicy.GetProtectedPaths(),
                p => p.Equals(WindowsPaths.Expand(temp), StringComparison.OrdinalIgnoreCase));

            WindowsSafetyPolicy.RemoveProtectedPath(temp);
            Assert.DoesNotContain(WindowsSafetyPolicy.GetProtectedPaths(),
                p => p.Equals(WindowsPaths.Expand(temp), StringComparison.OrdinalIgnoreCase));
        }
        finally
        {
            foreach (var p in original) WindowsSafetyPolicy.AddProtectedPath(p);
        }
    }

    [Fact]
    public void ProtectListEntryProtectsItsChildren()
    {
        var temp = Path.Combine(Path.GetTempPath(), "worm-protect-parent-" + Guid.NewGuid().ToString("N"));
        WindowsSafetyPolicy.AddProtectedPath(temp);
        try
        {
            var child = Path.Combine(temp, "nested", "cache");
            var verdict = WindowsSafetyPolicy.Evaluate(child, probeLiveness: false);
            Assert.True(verdict.IsBlocked);
            Assert.Equal(SafetyReason.UserProtectList, verdict.Reason);
        }
        finally
        {
            WindowsSafetyPolicy.RemoveProtectedPath(temp);
        }
    }
}

public class AgeGateTests
{
    [Fact]
    public void ZeroAgeAlwaysPasses()
    {
        Assert.True(WindowsScanCatalog.PassesAge(Environment.CurrentDirectory, 0));
    }

    [Fact]
    public void FreshFileFailsAgeGate()
    {
        var file = Path.Combine(Path.GetTempPath(), "worm-age-" + Guid.NewGuid().ToString("N"));
        File.WriteAllText(file, "x");
        try
        {
            Assert.False(WindowsScanCatalog.PassesAge(file, 7));
        }
        finally
        {
            File.Delete(file);
        }
    }

    [Fact]
    public void OldFilePassesAgeGate()
    {
        var file = Path.Combine(Path.GetTempPath(), "worm-age-old-" + Guid.NewGuid().ToString("N"));
        File.WriteAllText(file, "x");
        try
        {
            File.SetLastWriteTimeUtc(file, DateTime.UtcNow.AddDays(-30));
            Assert.True(WindowsScanCatalog.PassesAge(file, 7));
        }
        finally
        {
            File.Delete(file);
        }
    }

    [Fact]
    public void MissingPathFailsAgeGate()
    {
        var missing = Path.Combine(Path.GetTempPath(), "definitely-not-here-" + Guid.NewGuid().ToString("N"));
        Assert.False(WindowsScanCatalog.PassesAge(missing, 7));
    }

    [Fact]
    public void MissingPathPassesZeroAgeGate()
    {
        // Age 0 short-circuits before the filesystem check; the scanner relies on
        // ExpandTargets having already filtered non-existent paths.
        var missing = Path.Combine(Path.GetTempPath(), "definitely-not-here-" + Guid.NewGuid().ToString("N"));
        Assert.True(WindowsScanCatalog.PassesAge(missing, 0));
    }
}
