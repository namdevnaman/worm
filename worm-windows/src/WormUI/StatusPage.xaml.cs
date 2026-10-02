using System;
using System.Windows.Controls;
using System.Windows.Threading;
using Worm.Core;

namespace Worm.UI;

public partial class StatusPage : Page
{
    private readonly DispatcherTimer _timer;

    public StatusPage()
    {
        InitializeComponent();

        _timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromSeconds(1)
        };
        _timer.Tick += (s, e) => UpdateMetrics();

        Loaded += (s, e) =>
        {
            UpdateMetrics();
            _timer.Start();
        };

        Unloaded += (s, e) => _timer.Stop();
    }

    private void UpdateMetrics()
    {
        var snap = WindowsHardwareSampler.Sample();

        TxtCpuVal.Text = $"{snap.CpuUsagePercent:0.0}%";
        PbCpu.Value = snap.CpuUsagePercent;
        TxtProcs.Text = $"Active Processes: {snap.ProcessCount}";

        TxtRamVal.Text = $"{snap.RamUsagePercent:0.0}%";
        PbRam.Value = snap.RamUsagePercent;
        TxtRamDetail.Text = $"{FormatBytes(snap.RamUsedBytes)} / {FormatBytes(snap.RamTotalBytes)}";

        TxtDiskVal.Text = $"{snap.DiskUsagePercent:0.0}%";
        PbDisk.Value = snap.DiskUsagePercent;
        TxtDiskDetail.Text = $"{FormatBytes(snap.DiskUsedBytes)} / {FormatBytes(snap.DiskTotalBytes)}";
    }

    private static string FormatBytes(long bytes)
    {
        double gb = bytes / (1024.0 * 1024.0 * 1024.0);
        return $"{gb:0.1} GB";
    }
}
