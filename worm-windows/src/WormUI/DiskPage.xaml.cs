using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using Worm.Core;

namespace Worm.UI;

public partial class DiskPage : Page
{
    /// <summary>Row shape the volume list binds to.</summary>
    public sealed class VolumeRow
    {
        public string Name { get; set; } = string.Empty;
        public string Detail { get; set; } = string.Empty;
        public double UsedPercent { get; set; }
    }

    private CancellationTokenSource? _cts;

    public DiskPage()
    {
        InitializeComponent();
        Loaded += async (s, e) => await LoadAsync(runAnalysis: true);
        Unloaded += (s, e) => { _cts?.Cancel(); _cts?.Dispose(); _cts = null; };
    }

    private long ThresholdBytes()
    {
        var tag = (CmbThreshold.SelectedItem as ComboBoxItem)?.Tag?.ToString();
        if (!long.TryParse(tag, out var mb)) mb = 500;
        return mb * 1024 * 1024;
    }

    private async System.Threading.Tasks.Task LoadAsync(bool runAnalysis)
    {
        BtnRefresh.IsEnabled = false;

        _cts?.Cancel();
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;

        PanelGaugeLoading.Visibility = Visibility.Visible;
        PanelGauge.Visibility = Visibility.Collapsed;

        if (runAnalysis)
        {
            PanelFoldersLoading.Visibility = Visibility.Visible;
            TxtFoldersEmpty.Visibility = Visibility.Collapsed;
            PanelFilesLoading.Visibility = Visibility.Visible;
            TxtFilesEmpty.Visibility = Visibility.Collapsed;
        }

        try
        {
            // Volume data is cheap; the folder and file walk is not.
            var summary = await System.Threading.Tasks.Task.Run(() => WindowsDiskAnalyzer.Measure(), ct)
                                          .ConfigureAwait(true);
            ct.ThrowIfCancellationRequested();

            TxtUsedBytes.Text = summary.FormattedUsed;
            TxtUsedOf.Text = "used of " + summary.FormattedTotal;
            TxtFreeBytes.Text = summary.FormattedFree;
            TxtPercent.Text = summary.PercentUsed + " used";
            TxtGaugeNote.Text = summary.GaugeNote;
            TxtGaugeNote.Foreground = BrushFor(summary.GaugeColorKey);
            BarUsed.Value = summary.UsedFraction * 100;

            VolumeList.ItemsSource = summary.Volumes
                .Select(v => new VolumeRow
                {
                    Name = string.IsNullOrWhiteSpace(v.Label) ? v.Name : $"{v.Name} {v.Label}",
                    Detail = $"{WormFormat.Bytes(v.UsedBytes)} / {v.FormattedTotal}",
                    UsedPercent = v.UsedFraction * 100
                })
                .ToList();

            PanelGauge.Visibility = Visibility.Visible;
            PanelGaugeLoading.Visibility = Visibility.Collapsed;

            if (!runAnalysis) return;

            var (folders, files) = await WindowsDiskAnalyzer
                .AnalyzeAsync(largeFileThresholdBytes: ThresholdBytes(), progress: null, ct: ct)
                .ConfigureAwait(true);

            ct.ThrowIfCancellationRequested();

            FolderList.ItemsSource = folders;
            TxtFoldersEmpty.Visibility = folders.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

            FileList.ItemsSource = files;
            TxtFilesEmpty.Visibility = files.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

            TxtHeader.Text = folders.Count > 0 || files.Count > 0
                ? $"{folders.Count} folders and {files.Count} files analysed. " +
                  "Large files are read-only; nothing is deleted here."
                : "Volume capacity, the folders taking the most space, and files worth knowing about.";
        }
        catch (OperationCanceledException)
        {
            // Navigated away.
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("DiskPage.LoadAsync", ex);
            MessageBox.Show($"Disk analysis failed: {ex.Message}",
                "Worm", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            PanelGaugeLoading.Visibility = Visibility.Collapsed;
            PanelFoldersLoading.Visibility = Visibility.Collapsed;
            PanelFilesLoading.Visibility = Visibility.Collapsed;
            BtnRefresh.IsEnabled = true;
        }
    }

    private Brush BrushFor(string key) => key switch
    {
        "Danger" => (Brush)FindResource("Danger"),
        "Warn" => (Brush)FindResource("Warn"),
        _ => (Brush)FindResource("Accent")
    };

    private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        => _ = LoadAsync(runAnalysis: true);

    private void CmbThreshold_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        // Only re-run once the page is actually loaded; the constructor sets the
        // default selection.
        if (IsLoaded) _ = LoadAsync(runAnalysis: true);
    }

    private void FolderRow_Click(object sender, MouseButtonEventArgs e)
    {
        if (((FrameworkElement)sender).DataContext is FolderSize folder)
            Reveal(folder.Path);
    }

    private void FileRow_Click(object sender, MouseButtonEventArgs e)
    {
        if (((FrameworkElement)sender).DataContext is LargeFile file)
            Reveal(file.Path);
    }

    /// <summary>Opens Explorer with the item selected rather than launching it.</summary>
    private static void Reveal(string path)
    {
        try
        {
            if (File.Exists(path))
            {
                Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"")
                {
                    UseShellExecute = true
                });
            }
            else if (Directory.Exists(path))
            {
                Process.Start(new ProcessStartInfo(path) { UseShellExecute = true });
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("DiskPage.Reveal", ex);
        }
    }
}
