using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class LeftoversPage : Page
{
    public class OrphanDisplay
    {
        public string AppName { get; set; } = string.Empty;
        public string Path { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public string FormattedSize => FormatBytes(SizeBytes);
    }

    private List<OrphanDisplay> _orphans = new();

    public LeftoversPage()
    {
        InitializeComponent();
        Loaded += (s, e) => RefreshOrphans();
    }

    private void BtnScanOrphans_Click(object sender, RoutedEventArgs e)
    {
        RefreshOrphans();
    }

    private void RefreshOrphans()
    {
        BtnScanOrphans.IsEnabled = false;
        try
        {
            var raw = WindowsOrphanDetector.DetectOrphans();
            _orphans = raw.Select(o => new OrphanDisplay
            {
                AppName = o.AppName,
                Path = o.Path,
                SizeBytes = o.SizeBytes
            }).ToList();

            OrphansGrid.ItemsSource = _orphans;
            TxtOrphanCount.Text = $"{_orphans.Count} found ({FormatBytes(_orphans.Sum(o => o.SizeBytes))})";
            BtnCleanOrphans.IsEnabled = _orphans.Count > 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Error detecting leftovers: {ex.Message}", "Worm", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            BtnScanOrphans.IsEnabled = true;
        }
    }

    private async void BtnCleanOrphans_Click(object sender, RoutedEventArgs e)
    {
        if (MessageBox.Show($"Move {_orphans.Count} uninstalled application leftover folders to Recycle Bin?", 
                            "Confirm Leftover Shredding", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            return;

        BtnCleanOrphans.IsEnabled = false;
        int cleaned = 0;

        foreach (var orphan in _orphans)
        {
            bool ok = await WindowsReclaimer.CleanTargetAsync(orphan.Path, DeleteMode.RecycleBin);
            if (ok) cleaned++;
        }

        MessageBox.Show($"Cleaned {cleaned} leftover folders.", "Worm", MessageBoxButton.OK, MessageBoxImage.Information);
        RefreshOrphans();
    }

    private static string FormatBytes(long bytes)
    {
        string[] suffixes = { "B", "KB", "MB", "GB", "TB" };
        int counter = 0;
        decimal number = bytes;
        while (Math.Round(number / 1024) >= 1)
        {
            number /= 1024;
            counter++;
        }
        return $"{number:n1} {suffixes[counter]}";
    }
}
