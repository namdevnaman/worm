using System;
using System.IO;
using System.Windows;
using System.Windows.Threading;
using ModernWpf;
using Worm.Core;

namespace Worm.UI;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        // Install crash capture BEFORE anything else can throw.
        WindowsCrashLog.Install();

        // A themed startup failure must never abort the process silently.
        DispatcherUnhandledException += OnDispatcherUnhandledException;

        base.OnStartup(e);

        try
        {
            ThemeManager.Current.ApplicationTheme = ApplicationTheme.Dark;
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("OnStartup.ThemeManager", ex);
        }

        LogStartup();
    }

    private void LogStartup()
    {
        try
        {
            var dir = WindowsPaths.LogDir;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);
            File.AppendAllText(
                WindowsPaths.DeletionLog.Replace("deletions.tsv", "startup.log"),
                $"{DateTime.UtcNow:O}\tlaunched\t{Environment.Version}\t{Environment.ProcessPath}\n");
        }
        catch
        {
            // Ignore: logging must never block launch.
        }
    }

    private void OnDispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
    {
        WindowsCrashLog.Write("DispatcherUnhandledException", e.Exception);

        MessageBox.Show(
            $"Worm hit an unexpected error.\n\n{e.Exception.Message}\n\n" +
            $"A report was written to:\n{WindowsCrashLog.LogDirectory}",
            "Worm", MessageBoxButton.OK, MessageBoxImage.Error);

        e.Handled = true;
    }
}
