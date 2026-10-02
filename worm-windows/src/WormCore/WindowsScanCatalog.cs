using System;
using System.Collections.Generic;
using System.IO;

namespace Worm.Core;

public record CleanRule(
    string Id,
    string Name,
    string Category,
    string Description,
    RiskLevel Risk,
    string PathExpression,
    bool IsDirectory = true,
    string SearchPattern = "*"
);

/// <summary>
/// Scan catalog covering Windows System, Developers (Visual Studio, VS Code, NuGet, npm, pip, cargo),
/// web browsers, and delivery optimization caches.
/// </summary>
public static class WindowsScanCatalog
{
    public static IReadOnlyList<CleanRule> GetRules()
    {
        var local = WindowsPaths.LocalAppData;
        var appData = WindowsPaths.AppData;
        var user = WindowsPaths.UserProfile;

        return new List<CleanRule>
        {
            // --- Windows System Caches ---
            new("sys.temp.user", "User Temporary Files", "Windows System", 
                "Temporary application files and system installers", RiskLevel.Regenerable, 
                Path.Combine(local, "Temp")),

            new("sys.thumbcache", "Explorer Thumbnail Cache", "Windows System", 
                "Cached Windows Explorer image and video preview thumbnails", RiskLevel.Regenerable, 
                Path.Combine(local, "Microsoft", "Windows", "Explorer"), false, "thumbcache_*.db"),

            new("sys.delivery.opt", "Delivery Optimization Files", "Windows System", 
                "Cached Windows Update peer-to-peer distribution data", RiskLevel.Regenerable, 
                Path.Combine(WindowsPaths.WindowsDir, "SoftwareDistribution", "DeliveryOptimization")),

            new("sys.wer.reports", "Windows Error Reports", "Windows System", 
                "Crash dump logs and telemetry diagnostics reports", RiskLevel.Regenerable, 
                Path.Combine(local, "Microsoft", "Windows", "WER", "ReportArchive")),

            new("sys.d3d.cache", "DirectX Shader Cache", "Windows System", 
                "Compiled GPU DirectX shader caches", RiskLevel.Regenerable, 
                Path.Combine(local, "D3DSCache")),

            // --- Developer Build & Package Toolchains ---
            new("dev.vs.cache", "Visual Studio Component Cache", "Developer Tools", 
                "Cached MEF component catalogs and IntelliSense database indices", RiskLevel.Regenerable, 
                Path.Combine(local, "Microsoft", "VisualStudio")),

            new("dev.nuget.http", "NuGet HTTP Cache", "Developer Tools", 
                "Downloaded package archive responses", RiskLevel.ReDownload, 
                Path.Combine(local, "NuGet", "v3-cache")),

            new("dev.vscode.workspace", "VS Code Workspace Storage", "Developer Tools", 
                "Internal editor workspace metadata and cache states", RiskLevel.Regenerable, 
                Path.Combine(appData, "Code", "User", "workspaceStorage")),

            new("dev.npm.cache", "npm Package Cache", "Developer Tools", 
                "Downloaded Node.js tarballs and index records", RiskLevel.ReDownload, 
                Path.Combine(local, "npm-cache")),

            new("dev.pnpm.store", "pnpm Store Cache", "Developer Tools", 
                "Global pnpm hardlink cache store", RiskLevel.ReDownload, 
                Path.Combine(local, "pnpm", "store")),

            new("dev.cargo.cache", "Rust Cargo Registry", "Developer Tools", 
                "Cached crates.io tarballs and git checkout indices", RiskLevel.ReDownload, 
                Path.Combine(user, ".cargo", "registry", "cache")),

            new("dev.pip.cache", "Python pip Cache", "Developer Tools", 
                "Downloaded Python wheels and source distributions", RiskLevel.ReDownload, 
                Path.Combine(local, "pip", "cache")),

            new("dev.gradle.caches", "Gradle Build Caches", "Developer Tools", 
                "Downloaded Gradle dependencies and task execution caches", RiskLevel.ReDownload, 
                Path.Combine(user, ".gradle", "caches")),

            // --- Web Browser Caches ---
            new("browser.chrome.cache", "Google Chrome Cache", "Web Browsers", 
                "Temporary web assets and HTTP responses for Chrome", RiskLevel.Regenerable, 
                Path.Combine(local, "Google", "Chrome", "User Data", "Default", "Cache")),

            new("browser.edge.cache", "Microsoft Edge Cache", "Web Browsers", 
                "Temporary web assets and HTTP responses for Edge", RiskLevel.Regenerable, 
                Path.Combine(local, "Microsoft", "Edge", "User Data", "Default", "Cache")),

            new("browser.brave.cache", "Brave Browser Cache", "Web Browsers", 
                "Cached web files for Brave", RiskLevel.Regenerable, 
                Path.Combine(local, "BraveSoftware", "Brave-Browser", "User Data", "Default", "Cache"))
        };
    }
}
