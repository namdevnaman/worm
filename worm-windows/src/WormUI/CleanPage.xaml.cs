using System;
using System.Collections.Generic;
using System.Linq;
using System.Windows;
using System.Windows.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class CleanPage : Page
{
    public class DisplayItem
    {
        public CleanRule Rule { get; set; } = null!;
        public string Path { get; set; } = string.Empty;
        public long SizeBytes { get; set; }
        public int FileCount { get; set; }
        public bool IsBlocked { get; set; }
        public string FormattedSize => FormatBytes(SizeBytes);
        public string StatusText => IsBlocked ? "Protected" : "Cleanable";
    }

    private List<DisplayItem> _items = new();

    public CleanPage()
    {
        InitializeComponent();
        Loaded += async (s, e) => await RefreshScanAsync();
    }

    private async void BtnScan_Click(object sender, RoutedEventArgs e)
    {
        await RefreshScanAsync();
    }

    private async System.Threading.Tasks.Task RefreshScanAsync()
    {
        BtnScan.IsEnabled = false;
        BtnClean.IsEnabled = false;

        try
        {
            var summary = await WindowsScanner.RunScanAsync();
            _items = summary.Items.Select(i => new DisplayItem
            {
                Rule = i.Rule,
                Path = i.Path,
                SizeBytes = i.SizeBytes,
                FileCount = i.FileCount,
                IsBlocked = i.IsBlocked
            }).ToList();

            ItemsGrid.ItemsSource = _items;
            TxtTotalSize.Text = FormatBytes(summary.TotalCleanableBytes);
            BtnClean.IsEnabled = summary.TotalCleanableBytes > 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Scan error: {ex.Message}", "Worm", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            BtnScan.IsEnabled = true;
        }
    }

    private async void BtnClean_Click(object sender, RoutedEventArgs e)
    {
        var mode = CmbDeleteMode.SelectedIndex == 1 ? DeleteMode.Permanent : DeleteMode.RecycleBin;
        var confirmMsg = mode == DeleteMode.Permanent 
            ? "Are you sure you want to PERMANENTLY delete cleanable cache files?" 
            : "Files will be safely moved to your Windows Recycle Bin. Proceed?";

        if (MessageBox.Show(confirmMsg, "Worm Cleaner", MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
            return;

        BtnClean.IsEnabled = false;
        int cleanedCount = 0;

        foreach (var item in _items.Where(i => !i.IsBlocked))
        {
            bool success = await WindowsReclaimer.CleanTargetAsync(item.Path, mode);
            if (success) cleanedCount++;
        }

        MessageBox.Show($"Cleaned {cleanedCount} target locations successfully.", "Worm", MessageBoxButton.OK, MessageBoxImage.Information);
        await RefreshScanAsync();
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
