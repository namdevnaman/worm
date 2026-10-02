using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace Worm.Core;

/// <summary>
/// Best-effort crash recorder. WPF swallows startup failures, so without this the app
/// would exit instantly with no visible error and no trace left behind.
/// Every unhandled exception on the UI thread, the app domain, and the task scheduler
/// is appended to %LOCALAPPDATA%\Worm\Logs\crash.log before the process dies.
/// </summary>
public static class WindowsCrashLog
{
    private static readonly object Gate = new();
    private static bool _hooked;

    public static string LogDirectory => WindowsPaths.LogDir;

    private static string LogFile => System.IO.Path.Combine(WindowsPaths.LogDir, "crash.log");

    public static void Install()
    {
        lock (Gate)
        {
            if (_hooked) return;
            _hooked = true;

            AppDomain.CurrentDomain.UnhandledException += (_, e) =>
                Write("AppDomain.UnhandledException", e.ExceptionObject as Exception ?? new Exception(e.ExceptionObject?.ToString()));

            System.Threading.Tasks.TaskScheduler.UnobservedTaskException += (_, e) =>
                Write("TaskScheduler.UnobservedTaskException", e.Exception);
        }
    }

    public static void Write(string source, Exception? ex)
    {
        try
        {
            var dir = WindowsPaths.LogDir;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            var sb = new StringBuilder();
            sb.AppendLine("---- Worm crash report ----");
            sb.AppendLine($"utc        : {DateTime.UtcNow:O}");
            sb.AppendLine($"source     : {source}");
            sb.AppendLine($"os         : {Environment.OSVersion}");
            sb.AppendLine($"runtime    : {Environment.Version}");
            sb.AppendLine($"64-bit proc: {Environment.Is64BitProcess}");
            sb.AppendLine($"exe        : {Safe(() => Environment.ProcessPath)}");
            sb.AppendLine($"cmdline    : {Safe(() => string.Join(' ', Environment.GetCommandLineArgs()))}");
            sb.AppendLine($"cwd        : {Safe(() => Directory.GetCurrentDirectory())}");
            sb.AppendLine($"exception  : {ex?.GetType().FullName}");
            sb.AppendLine(ex?.ToString() ?? "(none)");
            sb.AppendLine();

            lock (Gate)
            {
                File.AppendAllText(LogFile, sb.ToString(), Encoding.UTF8);
            }
        }
        catch
        {
            // Never let logging itself take the process down.
        }
    }

    private static string Safe(Func<string?> get)
    {
        try { return get() ?? "(null)"; }
        catch (Exception e) { return "(error: " + e.Message + ")"; }
    }
}
