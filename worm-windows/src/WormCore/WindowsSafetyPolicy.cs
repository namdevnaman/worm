using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Microsoft.Win32;

namespace Worm.Core;

/// <summary>
/// Why a path was refused. Ported from the macOS SafetyPolicy taxonomy so the
/// two platforms explain themselves identically to the user.
/// </summary>
public enum SafetyReason
{
    None = 0,

    // ---- Hard: structural, never overridable, never cleared by the protect list ----
    UserDataRoot,
    SystemCritical,
    CriticalSystemPath,
    VolumeRoot,
    SymlinkedAncestor,
    DeveloperToolchainState,
    CredentialStore,
    SoftwareUpdateStaging,
    EndpointSecurityCache,
    SmallUiState,
    ProtectedAppData,
    NotInsideCleanableRoot,
    PathInvalid,
    IdentityChanged,
    WritableProtectedAncestor,

    // ---- Soft: evidence-based and time-sensitive, but still never deleted while true ----
    LiveApplicationCache,
    FileInUse,
    UserProtectList,
}

/// <summary>
/// Three-state verdict. AllowWithWarning is load-bearing: a running app's cache
/// can be cleaned, some bytes just get recreated immediately. Blocking outright
/// on liveness made the app look broken while hiding reclaimable space.
/// </summary>
public enum SafetyVerdictKind
{
    Allow,
    AllowWithWarning,
    Blocked,
}

public readonly record struct SafetyVerdict(SafetyVerdictKind Kind, SafetyReason Reason)
{
    public static readonly SafetyVerdict Allow = new(SafetyVerdictKind.Allow, SafetyReason.None);
    public bool IsAllowed => Kind != SafetyVerdictKind.Blocked;
    public bool HasWarning => Kind == SafetyVerdictKind.AllowWithWarning;
    public bool IsBlocked => Kind == SafetyVerdictKind.Blocked;

    public static string Title(SafetyReason r) => r switch
    {
        SafetyReason.UserDataRoot => "Personal folder",
        SafetyReason.SystemCritical => "System component",
        SafetyReason.CriticalSystemPath => "Protected system path",
        SafetyReason.VolumeRoot => "Volume root",
        SafetyReason.SymlinkedAncestor => "Symlinked parent folder",
        SafetyReason.DeveloperToolchainState => "Developer toolchain state",
        SafetyReason.CredentialStore => "Credential store",
        SafetyReason.SoftwareUpdateStaging => "Windows Update staging",
        SafetyReason.EndpointSecurityCache => "Endpoint security cache",
        SafetyReason.SmallUiState => "Windows shell state",
        SafetyReason.ProtectedAppData => "Protected app data",
        SafetyReason.NotInsideCleanableRoot => "Outside a cleanable folder",
        SafetyReason.PathInvalid => "Invalid path",
        SafetyReason.IdentityChanged => "Changed during review",
        SafetyReason.WritableProtectedAncestor => "Writable parent folder",
        SafetyReason.LiveApplicationCache => "App is running",
        SafetyReason.FileInUse => "File in use",
        SafetyReason.UserProtectList => "On your protect list",
        _ => "Blocked",
    };

    public static string Detail(SafetyReason r) => r switch
    {
        SafetyReason.UserDataRoot =>
            "Personal folders are never a cleanup source or target. Worm will not touch this.",
        SafetyReason.SystemCritical =>
            "This belongs to Windows itself and is required for the system to run.",
        SafetyReason.CriticalSystemPath =>
            "This path is on the deny list. Worm never deletes it.",
        SafetyReason.VolumeRoot =>
            "A drive root cannot be deleted.",
        SafetyReason.SymlinkedAncestor =>
            "A parent folder is a link, so a sweep here could escape into your data.",
        SafetyReason.DeveloperToolchainState =>
            "Toolchains, archives and signing state are not rebuildable cache.",
        SafetyReason.CredentialStore =>
            "Password stores and key material are never cleaned.",
        SafetyReason.SoftwareUpdateStaging =>
            "Windows owns this tree. Its age cannot prove it stays inactive.",
        SafetyReason.EndpointSecurityCache =>
            "Security agents treat deletion from this tree as tampering.",
        SafetyReason.SmallUiState =>
            "Reclaims almost nothing and leaves blank or re-downloading UI.",
        SafetyReason.ProtectedAppData =>
            "This app's data is explicitly protected from removal.",
        SafetyReason.NotInsideCleanableRoot =>
            "Not inside any folder a scan rule is allowed to produce targets in. " +
            "This bounds the damage a buggy rule can do.",
        SafetyReason.PathInvalid =>
            "The path is not absolute, contains traversal, or has control characters.",
        SafetyReason.IdentityChanged =>
            "The item was replaced while you were reviewing it.",
        SafetyReason.WritableProtectedAncestor =>
            "A writable parent folder would turn a privileged delete into an escalation.",
        SafetyReason.LiveApplicationCache =>
            "An app is using this right now. Some bytes will come straight back.",
        SafetyReason.FileInUse =>
            "A process holds a file open here.",
        SafetyReason.UserProtectList =>
            "You added this path to your protect list. It protects itself and everything inside it.",
        _ => string.Empty,
    };
}

/// <summary>
/// Fail-safe policy. Two layers, both mandatory:
///
///   1. Hard blocks. Structural paths that are never cleaned, matched
///      prefix-aware and case-insensitively (NTFS is case-insensitive, so
///      C:\WINDOWS is the same inode as C:\Windows).
///   2. The cleanable-root allowlist. Derived from the scan catalog rather than
///      hand-maintained, so a buggy or widened rule still cannot delete outside
///      a folder the catalog declares cleanable. A hand-kept list silently
///      drifted on macOS and refused 228 MB of a tool's own cache as
///      "outside a cleanable folder"; deriving it makes that class of bug
///      impossible.
/// </summary>
public static class WindowsSafetyPolicy
{
    // ------------------------------------------------------------------ user protect list
    private static readonly List<string> UserProtectList = new();
    private static readonly object LockObj = new();

    static WindowsSafetyPolicy() => ReloadUserProtectList();

    public static void ReloadUserProtectList()
    {
        lock (LockObj)
        {
            UserProtectList.Clear();
            if (!File.Exists(WindowsPaths.ProtectFile)) return;
            try
            {
                foreach (var line in File.ReadAllLines(WindowsPaths.ProtectFile))
                {
                    var trimmed = line.Trim();
                    if (!string.IsNullOrEmpty(trimmed) && !trimmed.StartsWith('#'))
                        UserProtectList.Add(WindowsPaths.Expand(trimmed));
                }
            }
            catch { }
        }
    }

    public static IReadOnlyList<string> GetProtectedPaths()
    {
        lock (LockObj) return UserProtectList.ToList();
    }

    public static void AddProtectedPath(string path)
    {
        var expanded = WindowsPaths.Expand(path);
        lock (LockObj)
        {
            if (!UserProtectList.Contains(expanded, StringComparer.OrdinalIgnoreCase))
            {
                UserProtectList.Add(expanded);
                try { File.AppendAllLines(WindowsPaths.ProtectFile, new[] { expanded }); } catch { }
            }
        }
    }

    public static void RemoveProtectedPath(string path)
    {
        var expanded = WindowsPaths.Expand(path);
        lock (LockObj)
        {
            UserProtectList.RemoveAll(p => p.Equals(expanded, StringComparison.OrdinalIgnoreCase));
            try { File.WriteAllLines(WindowsPaths.ProtectFile, UserProtectList); } catch { }
        }
    }

    // ------------------------------------------------------- personal folders (hard)
    /// <summary>
    /// Known folders resolved through the registry rather than only
    /// Environment.SpecialFolder, because OneDrive and domain policies relocate
    /// Desktop/Documents/Pictures at per-user level. Hardcoding
    /// C:\Users\x\Documents would be wrong on a domain-joined machine.
    /// </summary>
    private static HashSet<string> BuildKnownFolders()
    {
        var set = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        void Add(Environment.SpecialFolder f)
        {
            try
            {
                var p = Environment.GetFolderPath(f);
                if (!string.IsNullOrWhiteSpace(p)) set.Add(Normalize(p));
            }
            catch { }
        }

        Add(Environment.SpecialFolder.DesktopDirectory);
        Add(Environment.SpecialFolder.MyDocuments);
        Add(Environment.SpecialFolder.MyPictures);
        Add(Environment.SpecialFolder.MyMusic);
        Add(Environment.SpecialFolder.MyVideos);
        Add(Environment.SpecialFolder.Favorites);
        Add(Environment.SpecialFolder.CommonApplicationData);

        // NOTE: UserProfile is deliberately NOT added here. It is protected as a
        // leaf, but every AppData, .npm and .cargo folder lives beneath it, so
        // treating it as a contents folder made the safety policy refuse every
        // single scan rule as UserDataRoot and left every list blank.

        // Conventional folder names, added only when they actually exist.
        // SpecialFolder does not resolve every one of these on every OS, and the
        // macOS build protects them by a static name list too.
        foreach (var name in new[]
                 {
                     "Documents", "Desktop", "Downloads", "Pictures", "Music", "Videos",
                     "Saved Games", "Favorites", "OneDrive"
                 })
        {
            var candidate = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), name);
            try
            {
                if (Directory.Exists(candidate) || File.Exists(candidate))
                    set.Add(Normalize(candidate));
            }
            catch { }
        }

        // Registry overrides win over SpecialFolder for redirected folders.
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders");
            if (key != null)
            {
                foreach (var name in new[]
                         {
                             "Desktop", "Personal", "My Pictures", "My Music", "My Video",
                             "{374DE290-123F-4565-9164-39C4925E467B}", // Downloads
                             "Favorites", "{4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4}", // Saved Games
                             "PersonalFolder", "OneDrive"
                         })
                {
                    var raw = key.GetValue(name) as string;
                    if (string.IsNullOrWhiteSpace(raw)) continue;
                    try
                    {
                        // Values may carry the ~2>&1 environment block.
                        var env = Environment.ExpandEnvironmentVariables(raw);
                        var path = env.StartsWith('~')
                            ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                                           env.TrimStart('~').TrimStart('\\'))
                            : env;
                        if (Directory.Exists(path) || !raw.Contains('%')) set.Add(Normalize(path));
                    }
                    catch { }
                }
            }
        }
        catch { }

        return set;
    }

    private static readonly Lazy<HashSet<string>> KnownFolders = new(BuildKnownFolders);

    // ------------------------------------------------------ hard system prefixes
    /// <summary>
    /// Prefix-aware, slash-aware, case-insensitive. The old implementation
    /// compared with string equality only, which blocked "C:\Windows\System32"
    /// but happily allowed "C:\Windows\System32\drivers".
    /// </summary>
    private static IEnumerable<string> HardBlockedPrefixes()
    {
        var w = WindowsPaths.WindowsDir;
        yield return w;
        yield return Path.Combine(w, "System32");
        yield return Path.Combine(w, "SysWOW64");
        yield return Path.Combine(w, "Boot");
        yield return Path.Combine(w, "LiveKernelReports");
        yield return Path.Combine(w, "assembly");
        yield return Path.Combine(w, "servicing");
        yield return Path.Combine(w, "WinSxS");
        yield return WindowsPaths.ProgramFiles;
        yield return WindowsPaths.ProgramFilesX86;
        yield return Path.Combine(WindowsPaths.ProgramData, "Package Cache");
        yield return Path.Combine(WindowsPaths.ProgramData, "Microsoft", "Windows Defender");
        yield return Path.Combine(w, "System32", "config"); // SAM / SECURITY / SYSTEM hives
        yield return Path.Combine(w, "System32", "spool", "drivers");
    }

    // ----------------------------------------------- developer toolchain (hard)
    /// <summary>
    /// Toolchain state is not rebuildable cache. Deliberately excludes
    /// Hugging Face / Torch model caches: refusing those hid 4.8 GB of genuinely
    /// reclaimable space on macOS. They are surfaced with a re-download badge
    /// instead.
    /// </summary>
    private static readonly string[] ToolchainRelativePrefixes =
    {
        @".gradle\caches\modules-2",
        @".gradle\caches\jars-9",
        @".gradle\wrapper\dists",
        @".m2\repository",
        @".nuget\packages",
        @".conda\pkgs",
        @".docker\config.json",
        @"AppData\Roaming\Docker",
        @".vscode\extensions",
        @".ollama\models",
        @"scoop\apps",
        @"scoop\persist",
        @"Documents\My Games",
    };

    // ------------------------------------------------- credential stores (hard)
    private static readonly string[] CredentialRelativePrefixes =
    {
        @".ssh",
        @".gnupg",
        @".gpg",
        @".aws\credentials",
        @".kube\config",
        @".netrc",
        @".npmrc",
        @".pypirc",
        @".cargo\credentials",
        @".cargo\credentials.toml",
        @".gem\credentials",
        @"AppData\Roaming\Bitwarden",
        @"AppData\Roaming\1Password",
        @"AppData\Roaming\gnupg",
        @"AppData\Local\1Password",
        @"AppData\Local\Programs",
        @"AppData\Roaming\Docker Desktop",
    };

    // ------------------------------------------------ Windows shell UI state
    private static readonly string[] SmallUiStateRelativePrefixes =
    {
        @"AppData\Local\IconCache.db",
        @"AppData\Local\Microsoft\Windows\Explorer\iconcache",
        @"AppData\Local\Microsoft\Windows\Explorer\ExplorerStartupLog",
        @"AppData\Local\Microsoft\Windows\Explorer\Thumbnails",
        @"AppData\Local\Microsoft\Windows\INetCache\IE",
        @"AppData\Local\Microsoft\Windows\WebCache",
    };

    // -------------------------------- endpoint security (hard, anchored)
    /// <summary>
    /// These vendor names are far too generic to refuse anywhere, so the match
    /// is anchored to ProgramData exactly as the macOS version anchors it to
    /// /private/var/folders. Matching bare names anywhere would refuse ordinary
    /// user folders.
    /// </summary>
    private static readonly string[] EndpointSecurityMarkers =
    {
        "crowdstrike", "falcon", "sentinelone", "carbonblack", "cylance",
        "symantec", "mcafee", "sophos", "bitdefender", "trendmicro",
        "paloalto", "panw", "cortex", "tanium", "kaseya", "msmpeng",
    };

    private static bool MatchesEndpointSecurity(string path)
    {
        if (!path.StartsWith(WindowsPaths.ProgramData, StringComparison.OrdinalIgnoreCase))
            return false;

        var lower = path.ToLowerInvariant();
        return EndpointSecurityMarkers.Any(m => lower.Contains(m));
    }

    // ------------------------------------------------- protected app folders
    private static readonly HashSet<string> ProtectedAppFolders = new(StringComparer.OrdinalIgnoreCase)
    {
        "Microsoft", "Microsoft Office", "Windows", "WindowsApps",
        "Packages", "Microsoft.NET", "dotnet", "Common Files",
    };

    private static bool IsProtectedAppData(string path)
    {
        foreach (var folder in ProtectedAppFolders)
        {
            var full = Path.Combine(WindowsPaths.ProgramFiles, folder);
            if (IsUnder(path, full)) return true;
        }
        return false;
    }

    // ------------------------------------------------------------- cleanable roots
    private static readonly Lazy<HashSet<string>> CleanableRoots = new(() =>
        new HashSet<string>(WindowsScanCatalog.CleanableRoots(), StringComparer.OrdinalIgnoreCase));

    // ------------------------------------------------------------------ helpers
    public static string Normalize(string p)
    {
        try
        {
            var expanded = WindowsPaths.Expand(p);
            if (expanded.Length > 3) expanded = expanded.TrimEnd('\\');
            return expanded;
        }
        catch { return p.TrimEnd('\\'); }
    }

    /// <summary>
    /// True when <paramref name="path"/> is <paramref name="root"/> or lives inside it.
    ///
    /// Separator-agnostic on purpose. Hardcoding '\' silently fails on any path
    /// that uses a different separator, which made the whole policy untestable
    /// off Windows and would mis-handle any Windows root that arrived with a
    /// forward slash.
    /// </summary>
    public static bool IsUnder(string path, string root)
    {
        if (string.IsNullOrEmpty(path) || string.IsNullOrEmpty(root)) return false;
        if (path.Equals(root, StringComparison.OrdinalIgnoreCase)) return true;

        // Accept either separator on the boundary so mixed-separator input still
        // matches, then compare on the canonical form.
        var canonicalPath = NormalizeSeparators(path);
        var canonicalRoot = NormalizeSeparators(root).TrimEnd(DirectorySeparator);

        if (canonicalPath.Equals(canonicalRoot, StringComparison.OrdinalIgnoreCase)) return true;
        return canonicalPath.StartsWith(canonicalRoot + DirectorySeparator,
                                        StringComparison.OrdinalIgnoreCase);
    }

    internal const char DirectorySeparator = '\\';

    private static string NormalizeSeparators(string p)
        => p.Replace('/', '\\');


    /// <summary>
    /// Path relative to the user profile, or null when it is not under it.
    ///
    /// Separator-agnostic, for the same reason as <see cref="IsUnder"/>: the
    /// previous version appended a backslash to the prefix, so on any path that
    /// does not use one it returned null and the toolchain and credential checks
    /// were silently skipped instead of applied.
    /// </summary>
    internal static string? RelativeToUser(string path)
    {
        try
        {
            var user = NormalizeSeparators(WindowsPaths.UserProfile)
                .TrimEnd(DirectorySeparator);

            var candidate = NormalizeSeparators(path);
            if (candidate.Equals(user, StringComparison.OrdinalIgnoreCase)) return string.Empty;
            if (candidate.StartsWith(user + DirectorySeparator, StringComparison.OrdinalIgnoreCase))
                return candidate[(user.Length + 1)..];

            return null;
        }
        catch { return null; }
    }

    // ----------------------------------------------------------------- evaluate
    /// <summary>
    /// Full safety evaluation. Returns a verdict rather than a bool so the UI can
    /// distinguish "no" from "yes, but this app is running".
    /// </summary>
    public static SafetyVerdict Evaluate(
        string targetPath,
        bool probeLiveness = true,
        bool allowWindowsUpgradeStaging = false)
    {
        if (string.IsNullOrWhiteSpace(targetPath))
            return Block(SafetyReason.PathInvalid);

        string full;
        try
        {
            full = Path.GetFullPath(targetPath);
        }
        catch
        {
            return Block(SafetyReason.PathInvalid);
        }

        // Control characters and traversal in the raw input.
        if (targetPath.IndexOfAny(new[] { '\0', '\r', '\n' }) >= 0)
            return Block(SafetyReason.PathInvalid);

        full = full.TrimEnd('\\');
        if (full.Length == 0) full = targetPath;

        // A bare drive root.
        if (full.Length == 3 && full[1] == ':' && char.IsLetter(full[0]) && full[2] == '\\')
            return Block(SafetyReason.VolumeRoot);
        if (full.Length == 2 && full[1] == ':')
            return Block(SafetyReason.VolumeRoot);

        // The profile root and the Users container themselves, as leaves only.
        // Everything beneath the profile is fair game except the known folders
        // checked immediately after.
        var profileRoot = Normalize(WindowsPaths.UserProfile);
        if (full.Equals(profileRoot, StringComparison.OrdinalIgnoreCase))
            return Block(SafetyReason.UserDataRoot);

        var usersRoot = Path.GetPathRoot(profileRoot);
        if (!string.IsNullOrEmpty(usersRoot))
        {
            var users = Normalize(usersRoot + "Users");
            if (full.Equals(users, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(Path.GetFileName(full), "Users", StringComparison.OrdinalIgnoreCase) &&
                string.Equals(Directory.GetParent(full)?.FullName, users, StringComparison.OrdinalIgnoreCase))
            {
                return Block(SafetyReason.UserDataRoot);
            }
        }

        // Personal folders, via known-folder resolution (registry-redirected).
        if (KnownFolders.Value.Contains(full)) return Block(SafetyReason.UserDataRoot);
        foreach (var folder in KnownFolders.Value)
        {
            if (IsUnder(full, folder)) return Block(SafetyReason.UserDataRoot);
        }

        // Hard system prefixes, prefix-aware.
        foreach (var prefix in HardBlockedPrefixes())
        {
            if (IsUnder(full, prefix)) return Block(SafetyReason.CriticalSystemPath);
        }

        // Windows Update staging is owned by Windows and never cleaned here.
        var wu = Path.Combine(WindowsPaths.WindowsDir, "SoftwareDistribution");
        if (IsUnder(full, wu)) return Block(SafetyReason.SoftwareUpdateStaging);
        // Old Windows installations are reclaimable, but they are the rollback
        // path. They stay hard-blocked unless the caller explicitly opts in, which
        // only the opt-in category does, and only for items the user ticked.
        foreach (var leftover in new[]
                 {
                     @"C:\$WINDOWS.~BT", @"C:\$WINDOWS.~WS", @"C:\Windows.old",
                     @"C:\Windows\Panther", @"C:\$SysReset", @"C:\ESD"
                 })
        {
            if (!IsUnder(full, leftover)) continue;
            if (allowWindowsUpgradeStaging) break;
            return Block(SafetyReason.SoftwareUpdateStaging);
        }

        if (MatchesEndpointSecurity(full)) return Block(SafetyReason.EndpointSecurityCache);
        if (IsProtectedAppData(full)) return Block(SafetyReason.ProtectedAppData);

        var relative = RelativeToUser(full);
        if (relative != null)
        {
            foreach (var p in ToolchainRelativePrefixes)
                if (IsUnder(relative, p)) return Block(SafetyReason.DeveloperToolchainState);

            foreach (var p in CredentialRelativePrefixes)
                if (IsUnder(relative, p)) return Block(SafetyReason.CredentialStore);

            foreach (var p in SmallUiStateRelativePrefixes)
                if (IsUnder(relative, p)) return Block(SafetyReason.SmallUiState);

        }

        // The user's own protect list.
        lock (LockObj)
        {
            foreach (var protectedPath in UserProtectList)
                if (IsUnder(full, protectedPath)) return Block(SafetyReason.UserProtectList);
        }

        // Blast-radius allowlist. Checked last so the user sees the most
        // meaningful reason first.
        var roots = CleanableRoots.Value;
        if (roots.Count > 0)
        {
            var physical = Normalize(ResolvePhysicalPath(full));

            var insideLogical = false;
            foreach (var root in roots)
            {
                if (IsUnder(full, root)) { insideLogical = true; break; }
            }

            // Both the logical and the resolved path must be contained. A junction
            // that points outside every cleanable root is refused, while a link
            // that stays inside is fine.
            var insidePhysical = true;
            if (!string.Equals(physical, full, StringComparison.OrdinalIgnoreCase))
            {
                insidePhysical = false;
                foreach (var root in roots)
                {
                    if (IsUnder(physical, root)) { insidePhysical = true; break; }
                }
            }

            if (!insideLogical || !insidePhysical)
                return Block(SafetyReason.NotInsideCleanableRoot);
        }

        // Soft, time-sensitive.
        if (probeLiveness && WindowsLivenessProbe.IsUnderLiveApplication(full))
            return new SafetyVerdict(SafetyVerdictKind.AllowWithWarning, SafetyReason.LiveApplicationCache);

        if (probeLiveness && WindowsLivenessProbe.IsFileLocked(full))
            return Block(SafetyReason.FileInUse);

        return SafetyVerdict.Allow;
    }

    /// <summary>
    /// Resolves a path to its physical location, following any reparse point.
    ///
    /// The previous design refused anything with a reparse point anywhere up the
    /// chain. That was the same over-blocking mistake as treating the user
    /// profile as a contents folder: OneDrive Known Folder Backup alone turns
    /// Documents into a link, so on a very ordinary machine every rule would be
    /// refused and every list would come back blank.
    ///
    /// Instead of denying, resolve and verify. A link that stays inside a
    /// cleanable root is harmless; one that escapes is caught by the allowlist
    /// check, which now runs against the resolved path as well as the logical
    /// one. Returns the input unchanged when nothing needs resolving.
    /// </summary>
    internal static string ResolvePhysicalPath(string path)
    {
        try
        {
            var dir = new DirectoryInfo(path);
            if (!dir.Exists) return path;
            if ((dir.Attributes & FileAttributes.ReparsePoint) == 0) return path;

            var target = dir.ResolveLinkTarget(returnFinalTarget: true);
            var resolved = target?.FullName;
            return string.IsNullOrEmpty(resolved) ? path : resolved;
        }
        catch
        {
            return path;
        }
    }

    private static SafetyVerdict Block(SafetyReason reason)
        => new(SafetyVerdictKind.Blocked, reason);

    // ------------------------------------------------------ compatibility shim
    /// <summary>
    /// Legacy surface kept so the reclaimer and older call sites keep working.
    /// Prefer <see cref="Evaluate"/>.
    /// </summary>
    public static bool IsPathProtected(string targetPath, out string reason)
    {
        var verdict = Evaluate(targetPath);
        if (verdict.IsAllowed)
        {
            reason = verdict.HasWarning ? SafetyVerdict.Title(verdict.Reason) : string.Empty;
            return false;
        }
        reason = $"{SafetyVerdict.Title(verdict.Reason)}: {SafetyVerdict.Detail(verdict.Reason)}";
        return true;
    }
}
