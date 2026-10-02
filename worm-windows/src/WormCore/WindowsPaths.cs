using System;
using System.IO;

namespace Worm.Core;

/// <summary>
/// Centralized Windows directory resolver.
/// Resolves standard Windows system folders, AppData, LocalAppData, Temp, and developer paths.
/// </summary>
public static class WindowsPaths
{
    public static string UserProfile => Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    public static string LocalAppData => Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
    public static string AppData => Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData);
    public static string ProgramData => Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
    public static string WindowsDir => Environment.GetFolderPath(Environment.SpecialFolder.Windows);
    public static string ProgramFiles => Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
    public static string ProgramFilesX86 => Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
    public static string SystemDrive => Path.GetPathRoot(Environment.SystemDirectory) ?? "C:\\";

    public static string UserTemp => Path.GetTempPath();
    public static string WindowsTemp => Path.Combine(WindowsDir, "Temp");

    // Worm configuration & log directories
    public static string ConfigDir => Path.Combine(UserProfile, ".config", "worm");
    public static string LogDir => Path.Combine(LocalAppData, "Worm", "Logs");
    public static string DeletionLog => Path.Combine(LogDir, "deletions.tsv");
    public static string ProtectFile => Path.Combine(ConfigDir, "protect.txt");

    static WindowsPaths()
    {
        try
        {
            if (!Directory.Exists(ConfigDir)) Directory.CreateDirectory(ConfigDir);
            if (!Directory.Exists(LogDir)) Directory.CreateDirectory(LogDir);
        }
        catch { }
    }

    /// <summary>
    /// Expands environment variable expressions like %LOCALAPPDATA%, %USERPROFILE%, and ~.
    /// </summary>
    public static string Expand(string path)
    {
        if (string.IsNullOrWhiteSpace(path)) return string.Empty;

        var expanded = Environment.ExpandEnvironmentVariables(path);
        if (expanded.StartsWith("~\\") || expanded.StartsWith("~/"))
        {
            expanded = Path.Combine(UserProfile, expanded[2..]);
        }
        else if (expanded == "~")
        {
            expanded = UserProfile;
        }

        try
        {
            return Path.GetFullPath(expanded);
        }
        catch
        {
            return expanded;
        }
    }
}
