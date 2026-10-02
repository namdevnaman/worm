using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Threading;
using Worm.Core;

namespace Worm.UI;

public partial class StatusPage : Page
{
    private readonly DispatcherTimer _timer;

    public sealed class Fact
    {
        public string Label { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
    }

    public sealed class ProcessRow
    {
        public string Name { get; set; } = string.Empty;
        public int Pid { get; set; }
        public long WorkingSet { get; set; }
        public string FormattedMemory => WormFormat.Bytes(WorkingSet);
    }

    public sealed class CheckRow
    {
        public string Title { get; set; } = string.Empty;
        public string Detail { get; set; } = string.Empty;
        public string SeverityText { get; set; } = string.Empty;
        public Brush SeverityBrush { get; set; } = Brushes.Gray;
        public Brush SeveritySoft { get; set; } = Brushes.Transparent;
    }

    private readonly ObservableCollection<ProcessRow> _processes = new();
    private readonly ObservableCollection<CheckRow> _checks = new();

    public StatusPage()
    {
        InitializeComponent();

        ProcessList.ItemsSource = _processes;
        CheckList.ItemsSource = _checks;

        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _timer.Tick += (s, e) => Refresh();

        Loaded += (s, e) =>
        {
            PanelLoading.Visibility = Visibility.Visible;
            PanelMetrics.Visibility = Visibility.Collapsed;

            // Facts are gathered once, off the UI thread: doing registry and
            // process work in the first render makes the first frame slow.
            Task.Run(() => GatherFacts())
                 .ContinueWith(t =>
                 {
                     Dispatcher.Invoke(() =>
                     {
                         FactsList.ItemsSource = t.Result;
                         PanelLoading.Visibility = Visibility.Collapsed;
                         PanelMetrics.Visibility = Visibility.Visible;
                     });
                 });

            Refresh();
            _timer.Start();
        };

        Unloaded += (s, e) => _timer.Stop();
    }

    private void Refresh()
    {
        try
        {
            var snap = WindowsHardwareSampler.Sample();

            TxtCpu.Text = $"{snap.CpuUsagePercent:0.0}%";
            BarCpu.Value = snap.CpuUsagePercent;
            TxtCpuDetail.Text = $"{Environment.ProcessorCount} logical cores";

            TxtRam.Text = $"{snap.RamUsagePercent:0.0}%";
            BarRam.Value = snap.RamUsagePercent;
            TxtRamDetail.Text = $"{WormFormat.Bytes(snap.RamUsedBytes)} / {WormFormat.Bytes(snap.RamTotalBytes)}";

            TxtDiskFree.Text = WormFormat.Bytes(snap.DiskFreeBytes);
            BarDisk.Value = snap.DiskUsagePercent;
            TxtDiskDetail.Text = $"{WormFormat.Bytes(snap.DiskUsedBytes)} used of {WormFormat.Bytes(snap.DiskTotalBytes)}";

            TxtProcCount.Text = snap.ProcessCount.ToString();
            BarProc.Value = snap.ProcessCount > 0 ? Math.Min(100, snap.ProcessCount / 4.0) : 0;

            UpdateTopProcesses();
            UpdateChecks(snap);
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("StatusPage.Refresh", ex);
        }
    }

    /// <summary>
    /// Top processes by working set. Enumerating every process twice a second is
    /// wasteful, so this is bounded and tolerant of processes that exit mid-read.
    /// </summary>
    private void UpdateTopProcesses()
    {
        try
        {
            var top = new List<ProcessRow>(12);

            foreach (var p in Process.GetProcesses())
            {
                try
                {
                    long workingSet = 0;
                    try { workingSet = p.WorkingSet64; } catch { }
                    if (workingSet <= 0) continue;

                    top.Add(new ProcessRow
                    {
                        Name = string.IsNullOrEmpty(p.ProcessName) ? "(unknown)" : p.ProcessName,
                        Pid = SafePid(p),
                        WorkingSet = workingSet
                    });
                }
                catch { }
                finally { p.Dispose(); }
            }

            var ordered = top.OrderByDescending(r => r.WorkingSet).Take(10).ToList();

            _processes.Clear();
            foreach (var row in ordered) _processes.Add(row);
        }
        catch { }
    }

    private static int SafePid(Process p)
    {
        try { return p.Id; }
        catch { return 0; }
    }

    private void UpdateChecks(Worm.Core.HardwareSnapshot snap)
    {
        _checks.Clear();

        var good = (Brush)FindResource("Good");
        var warn = (Brush)FindResource("Warn");
        var danger = (Brush)FindResource("Danger");
        var goodSoft = (Brush)FindResource("GoodSoft");
        var warnSoft = (Brush)FindResource("WarnSoft");
        var dangerSoft = (Brush)FindResource("DangerSoft");

        void Add(string title, string detail, string severity, Brush brush, Brush soft)
            => _checks.Add(new CheckRow
            {
                Title = title, Detail = detail,
                SeverityText = severity, SeverityBrush = brush, SeveritySoft = soft
            });

        if (snap.DiskUsagePercent >= 92)
            Add("Disk is nearly full",
                $"{WormFormat.Bytes(snap.DiskFreeBytes)} free on the system drive. " +
                "Windows needs working space to update and page.",
                "Action needed", danger, dangerSoft);
        else if (snap.DiskUsagePercent >= 85)
            Add("Disk space is getting tight",
                $"{WormFormat.Bytes(snap.DiskFreeBytes)} free on the system drive.",
                "Notice", warn, warnSoft);
        else
            Add("Disk space is healthy",
                $"{WormFormat.Bytes(snap.DiskFreeBytes)} free on the system drive.",
                "OK", good, goodSoft);

        if (snap.RamUsagePercent >= 90)
            Add("Memory is under pressure",
                $"{snap.RamUsagePercent:0}% of physical memory is in use.",
                "Action needed", danger, dangerSoft);
        else if (snap.RamUsagePercent >= 75)
            Add("Memory use is elevated",
                $"{snap.RamUsagePercent:0}% of physical memory is in use.",
                "Notice", warn, warnSoft);
        else
            Add("Memory is healthy",
                $"{snap.RamUsagePercent:0}% of physical memory is in use.",
                "OK", good, goodSoft);

        if (snap.CpuUsagePercent >= 90)
            Add("CPU is saturated",
                $"{snap.CpuUsagePercent:0}% sustained across {Environment.ProcessorCount} cores.",
                "Action needed", danger, dangerSoft);
        else
            Add("CPU load is normal",
                $"{snap.CpuUsagePercent:0}% across {Environment.ProcessorCount} cores.",
                "OK", good, goodSoft);
    }

    private IReadOnlyList<Fact> GatherFacts()
    {
        var facts = new List<Fact>();

        facts.Add(new Fact { Label = "Edition", Value = ReadEdition() });
        facts.Add(new Fact { Label = "Version", Value = Environment.OSVersion.Version.ToString() });
        facts.Add(new Fact { Label = "Architecture", Value = Environment.Is64BitOperatingSystem ? "64-bit" : "32-bit" });
        facts.Add(new Fact { Label = "Logical cores", Value = Environment.ProcessorCount.ToString() });
        facts.Add(new Fact { Label = "Computer name", Value = Safe(() => Environment.MachineName) });
        facts.Add(new Fact { Label = "User", Value = Safe(() => Environment.UserName) });
        facts.Add(new Fact { Label = "Worm version", Value = Safe(() => AppVersion()) });
        facts.Add(new Fact { Label = "Uptime", Value = Safe(() =>
        {
            // TickCount wraps after ~24.8 days on some builds; treat overflow as unknown.
            var ms = Environment.TickCount64;
            return WormFormat.Uptime(TimeSpan.FromMilliseconds(ms));
        }) });

        facts.Add(new Fact { Label = "Install folder", Value = Safe(() => WindowsPaths.UserProfile) });
        facts.Add(new Fact { Label = "Log folder", Value = Safe(() => WindowsPaths.LogDir) });

        return facts;
    }

    private static string AppVersion()
    {
        var v = typeof(StatusPage).Assembly.GetName().Version;
        return v == null ? "unknown" : $"{v.Major}.{v.Minor}.{v.Build}";
    }

    private static string ReadEdition()
    {
        try
        {
            using var os = Microsoft.Win32.Registry.LocalMachine
                .OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion");
            return os?.GetValue("ProductName")?.ToString() ?? "Windows";
        }
        catch { return "Windows"; }
    }

    private static string Safe(Func<string> get)
    {
        try { return get() ?? "unknown"; }
        catch { return "unavailable"; }
    }
}
