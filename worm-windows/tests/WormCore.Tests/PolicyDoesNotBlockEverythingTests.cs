using System;
using System.IO;
using System.Linq;
using Worm.Core;
using Xunit;

namespace Worm.Core.Tests;

/// <summary>
/// Guards against the policy refusing everything.
///
/// A first version of <see cref="WindowsSafetyPolicy"/> added the user profile to
/// the set of "personal folders" and then blocked any path *beneath* it. Since
/// %LOCALAPPDATA%, %APPDATA%, .npm and .cargo all live under the profile, every
/// scan rule was refused as UserDataRoot and every list in the app came back
/// blank. The app still started, so nothing errored and it looked like a data
/// problem rather than a policy bug.
///
/// These tests assert the inverse of that failure: ordinary cache locations must
/// be cleanable, while genuine personal folders must not be.
/// </summary>
public class PolicyDoesNotBlockEverythingTests
{
    private static readonly string Profile = WindowsPaths.UserProfile;

    [Theory]
    [InlineData("AppData/Local")]
    [InlineData("AppData/Roaming")]
    [InlineData(".npm")]
    [InlineData(".cargo/registry/cache")]
    [InlineData(".gradle/caches/build-cache-1")]
    public void OrdinaryCacheFoldersUnderTheProfileAreNotPersonalFolders(string relative)
    {
        var path = Path.Combine(Profile, relative.Replace('/', Path.DirectorySeparatorChar));

        var verdict = WindowsSafetyPolicy.Evaluate(path, probeLiveness: false);

        Assert.False(verdict.IsBlocked,
            $"{relative} must not be refused as {verdict.Reason}; the profile is a leaf, " +
            "not a contents folder");

        Assert.NotEqual(SafetyReason.UserDataRoot, verdict.Reason);
    }

    [Theory]
    [InlineData("Documents")]
    [InlineData("Desktop")]
    [InlineData("Pictures")]
    [InlineData("Music")]
    [InlineData("Videos")]
    public void RealPersonalFoldersAreStillRefused(string folder)
    {
        // Only meaningful where the folder actually exists; SpecialFolder does not
        // resolve every one of these on every OS.
        if (!Directory.Exists(Path.Combine(Profile, folder))) return;

        var path = Path.Combine(Profile, folder, "anything");
        var verdict = WindowsSafetyPolicy.Evaluate(path, probeLiveness: false);

        Assert.True(verdict.IsBlocked, $"{folder} must be refused");
        Assert.Equal(SafetyReason.UserDataRoot, verdict.Reason);
    }

    [Fact]
    public void TheProfileRootItselfIsRefused()
    {
        var verdict = WindowsSafetyPolicy.Evaluate(Profile, probeLiveness: false);
        Assert.True(verdict.IsBlocked);
        Assert.Equal(SafetyReason.UserDataRoot, verdict.Reason);
    }

    [Fact]
    public void SystemPathsAreStillRefused()
    {
        foreach (var path in new[]
                 {
                     Path.Combine(WindowsPaths.WindowsDir, "System32"),
                     Path.Combine(WindowsPaths.WindowsDir, "System32", "drivers"),
                     Path.Combine(WindowsPaths.ProgramFiles, "Anything"),
                     Path.Combine(Path.GetPathRoot(WindowsPaths.WindowsDir) ?? "C:\\", "Windows.old"),
                 })
        {
            var verdict = WindowsSafetyPolicy.Evaluate(path, probeLiveness: false);
            Assert.True(verdict.IsBlocked, $"{path} must be refused");
        }
    }

    [Fact]
    public void CredentialAndToolchainPathsUnderTheProfileAreStillRefused()
    {
        foreach (var relative in new[] { @".ssh", @".gnupg", @".gradle\caches\modules-2", @".nuget\packages" })
        {
            var path = Path.Combine(Profile, relative);
            var verdict = WindowsSafetyPolicy.Evaluate(path, probeLiveness: false);
            Assert.True(verdict.IsBlocked, $"{relative} must be refused but was allowed");
        }
    }

    /// <summary>
    /// Every rule in the catalog must be able to produce at least one path that
    /// the policy does not refuse. If the allowlist or the personal-folder check
    /// ever collapses again, this fails before a build is ever shipped.
    /// </summary>
    [Fact]
    public void CatalogTargetsAreNotSystematicallyRefused()
    {
        var refusals = new System.Collections.Generic.List<string>();

        foreach (var rule in WindowsScanCatalog.GetRules())
        {
            // A Files rule's root is only a container; the rule's targets are the
            // matching files inside it, so the container itself is allowed to be a
            // protected location such as the profile root.
            if (rule.Kind == RuleKind.Files) continue;

            var basePath = WindowsSafetyPolicy.Normalize(rule.PathExpression);
            var verdict = WindowsSafetyPolicy.Evaluate(basePath, probeLiveness: false);

            if (verdict.IsBlocked)
            {
                refusals.Add($"{rule.Id} -> {verdict.Reason} ({basePath})");
            }
        }

        Assert.True(refusals.Count == 0,
            "These rule roots are refused by the policy, which would leave the " +
            "corresponding categories permanently empty:" +
            Environment.NewLine + string.Join(Environment.NewLine, refusals));
    }
}
