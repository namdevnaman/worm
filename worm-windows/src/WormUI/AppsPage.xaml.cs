using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.IO;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class AppsPage : Page
{
    public class AppRow : INotifyPropertyChanged
    {
        private bool _isSelected;

        public InstalledApp App { get; set; } = null!;
        public string Name => App.Name;
        public string Publisher => App.Publisher;
        public string Version => App.Version;
        public string FormattedSize => App.FormattedSize;
        private long _sizeBytes;
        public long SizeBytes
        {
            get => _sizeBytes != 0 ? _sizeBytes : App.SizeBytes;
            set
            {
                _sizeBytes = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(SizeBytes)));
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(FormattedSize)));
            }
        }

        public void SetSize(long bytes) => SizeBytes = bytes;

        public string StateText
        {
            get
            {
                if (App.IsProtected) return App.ProtectionReason;
                if (App.IsRunning) return "Running";
                return "Installed";
            }
        }

        /// <summary>Protected apps refuse to be ticked, like protected clean rows.</summary>
        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (App.IsProtected) value = false;
                if (_isSelected == value) return;
                _isSelected = value;
                OnPropertyChanged();
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
        private void OnPropertyChanged([CallerMemberName] string? name = null)
            => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    private List<AppRow> _all = new();
    private CancellationTokenSource? _cts;

    public AppsPage()
    {
        InitializeComponent();

        PanelLoading.Content = WormStates.Loading(
            "Worm is checking installed apps…",
            "Reading the Windows uninstall registry.");

        PanelEmpty.Content = WormStates.Empty(
            "No installed apps found",
            "Nothing is registered for removal in the Windows uninstall keys.");

        Loaded += async (s, e) => await LoadAsync();
        Unloaded += (s, e) => { _cts?.Cancel(); _cts?.Dispose(); _cts = null; };
    }

    private async System.Threading.Tasks.Task LoadAsync()
    {
        PanelLoading.Visibility = Visibility.Visible;
        PanelEmpty.Visibility = Visibility.Collapsed;
        PanelList.Visibility = Visibility.Collapsed;
        BtnRemove.IsEnabled = false;
        BtnRefresh.IsEnabled = false;

        _cts?.Cancel();
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;

        try
        {
            // Registry only. Measuring install directories walks thousands of
            // entries per app, which made the page look frozen for minutes, so
            // sizes are filled in afterwards instead of blocking the first paint.
            var apps = await System.Threading.Tasks.Task
                .Run(() => WindowsInstalledApps.Enumerate(probeRunning: true, measureSizes: false), ct)
                .ConfigureAwait(true);

            ct.ThrowIfCancellationRequested();

            _all = apps.Select(a => new AppRow { App = a }).ToList();
            TxtHeader.Text = $"{_all.Count} apps registered for removal. " +
                             "Protected and running apps cannot be ticked.";

            ApplyFilterAndSort();

            // Sizes are cosmetic, so they stream in rather than gating the list.
            if (!ct.IsCancellationRequested)
            {
                await MeasureSizesAsync(ct).ConfigureAwait(true);
            }
        }
        catch (OperationCanceledException)
        {
            // Navigated away mid-load.
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("AppsPage.LoadAsync", ex);
            MessageBox.Show($"Could not read installed apps: {ex.Message}",
                "Worm", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            PanelLoading.Visibility = Visibility.Collapsed;
            BtnRefresh.IsEnabled = true;
        }
    }

    /// <summary>
    /// Fills in app sizes in the background, cheapest first, updating the header
    /// as results arrive. Bounded so a pathological install directory cannot stall
    /// the page indefinitely.
    /// </summary>
    private async System.Threading.Tasks.Task MeasureSizesAsync(CancellationToken ct)
    {
        var work = new List<(int Index, string Path)>();
        var order = _all
            .Select((row, i) => (row, i))
            .Where(x => !string.IsNullOrWhiteSpace(x.row.App.InstallLocation))
            .OrderBy(x => x.row.SizeBytes)
            .ToList();

        int measured = 0;

        foreach (var (row, index) in order)
        {
            if (ct.IsCancellationRequested) return;
            if (measured++ > 120) break;

            var bytes = await System.Threading.Tasks.Task.Run(
                () => MeasureOne(row.App.InstallLocation), ct).ConfigureAwait(true);

            if (bytes < 0) continue;

            _all[index] = new AppRow { App = row.App, IsSelected = row.IsSelected };
            var updated = _all[index];
            updated.SetSize(bytes);
        }

        ApplyFilterAndSort();
        TxtHeader.Text = $"{_all.Count} apps registered for removal. " +
                         "Sizes are measured for the largest apps; smaller installs may show 0 B.";
    }

    private static long MeasureOne(string path)
    {
        try
        {
            if (!Directory.Exists(path)) return -1;

            long total = 0;
            var queue = new Queue<string>();
            queue.Enqueue(path);
            int visited = 0;

            while (queue.Count > 0 && visited++ < 300)
            {
                var dir = queue.Dequeue();
                try
                {
                    foreach (var file in Directory.GetFiles(dir))
                    {
                        try { total += new FileInfo(file).Length; } catch { }
                    }
                    foreach (var sub in Directory.GetDirectories(dir))
                    {
                        try
                        {
                            if ((File.GetAttributes(sub) & FileAttributes.ReparsePoint) != 0) continue;
                            queue.Enqueue(sub);
                        }
                        catch { }
                    }
                }
                catch { }
            }

            return total;
        }
        catch { return -1; }
    }

    private void ApplyFilterAndSort()
    {
        IEnumerable<AppRow> query = _all;

        var text = TxtFilter.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(text))
        {
            query = query.Where(r =>
                r.Name.Contains(text, StringComparison.OrdinalIgnoreCase) ||
                r.Publisher.Contains(text, StringComparison.OrdinalIgnoreCase));
        }

        query = CmbSort.SelectedIndex == 1
            ? query.OrderBy(r => r.Name, StringComparer.CurrentCultureIgnoreCase)
            : query.OrderByDescending(r => r.SizeBytes);

        var rows = query.ToList();

        PanelEmpty.Visibility = rows.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        PanelList.Visibility = rows.Count == 0 ? Visibility.Collapsed : Visibility.Visible;

        AppsGrid.ItemsSource = rows;
        UpdateSelection();
    }

    private void UpdateSelection()
    {
        var selected = _all.Where(r => r.IsSelected).ToList();
        TxtSelectedCount.Text = selected.Count.ToString();
        BtnRemove.IsEnabled = selected.Count > 0;
    }

    private void TxtFilter_TextChanged(object sender, TextChangedEventArgs e)
        => ApplyFilterAndSort();

    private void CmbSort_SelectionChanged(object sender, SelectionChangedEventArgs e)
        => ApplyFilterAndSort();

    private void BtnRefresh_Click(object sender, RoutedEventArgs e)
        => _ = LoadAsync();

    private async void BtnRemove_Click(object sender, RoutedEventArgs e)
    {
        var selected = _all.Where(r => r.IsSelected).ToList();
        if (selected.Count == 0) return;

        var names = string.Join("\n", selected.Take(8).Select(r => "  - " + r.Name));
        if (selected.Count > 8) names += $"\n  ... and {selected.Count - 8} more";

        var confirm =
            $"Worm will run the official uninstaller for:\n{names}\n\n" +
            "An uninstaller window will open for each app, one at a time.\n\n" +
            "Worm does not delete these files itself, so anything an uninstaller " +
            "leaves behind is still on disk. Continue?";

        if (MessageBox.Show(confirm, "Remove selected apps",
                MessageBoxButton.YesNo, MessageBoxImage.Warning) != MessageBoxResult.Yes)
        {
            return;
        }

        BtnRemove.IsEnabled = false;
        BtnRefresh.IsEnabled = false;

        try
        {
            foreach (var row in selected)
            {
                var result = await WindowsInstalledApps.RemoveAsync(row.App);
                if (!result.Success)
                {
                    MessageBox.Show(result.Message, "Worm",
                        MessageBoxButton.OK,
                        result.WasRefused ? MessageBoxImage.Warning : MessageBoxImage.Error);
                    break;
                }
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("AppsPage.BtnRemove_Click", ex);
            MessageBox.Show($"Removal stopped: {ex.Message}", "Worm",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            BtnRefresh.IsEnabled = true;
            await LoadAsync();
        }
    }
}
