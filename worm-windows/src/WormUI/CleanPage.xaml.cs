using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class CleanPage : Page
{
    public sealed class Row : INotifyPropertyChanged
    {
        private bool _isSelected;

        public ScanItemResult Item { get; set; } = null!;
        public CleanPage? Owner { get; set; }

        public string Label => Item.Label;
        public int FileCount => Item.FileCount;
        public string FormattedSize => Item.FormattedSize;
        public string StatusText => Item.StatusText;
        public bool IsBlocked => Item.IsBlocked;

        public string ShortPath
        {
            get
            {
                var p = Item.Path;
                var home = WindowsPaths.UserProfile;
                if (!string.IsNullOrEmpty(home) &&
                    p.StartsWith(home, StringComparison.OrdinalIgnoreCase))
                {
                    return "~" + p[home.Length..];
                }
                return p;
            }
        }

        /// <summary>Kept items can never be ticked, so their checkbox is inert.</summary>
        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (IsBlocked) value = false;
                if (_isSelected == value) return;
                _isSelected = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsSelected)));
                Owner?.OnSelectionChanged();
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }

    public sealed class CategoryRow : INotifyPropertyChanged
    {
        private string _subtitle = "Nothing found";
        private string _formattedSize = string.Empty;

        /// <summary>
        /// Null means "partly selected", which is the tri-state the checkbox draws
        /// as a bar. Recomputed whenever the category's selection changes.
        /// </summary>
        public bool? TriState
        {
            get
            {
                var cleanable = Rows.Where(r => !r.IsBlocked).ToList();
                if (cleanable.Count == 0) return false;

                var selected = cleanable.Count(r => r.IsSelected);
                if (selected == 0) return false;
                return selected == cleanable.Count ? true : null;
            }
        }

        public string Name { get; set; } = string.Empty;
        public List<Row> Rows { get; set; } = new();

        public string Subtitle
        {
            get => _subtitle;
            set { _subtitle = value; Raise(); }
        }

        public string FormattedSize
        {
            get => _formattedSize;
            set { _formattedSize = value; Raise(); }
        }

        private void Raise()
        {
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(null));
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(TriState)));
        }
        public event PropertyChangedEventHandler? PropertyChanged;
    }

    private readonly ObservableCollection<CategoryRow> _categories = new();
    private readonly Dictionary<string, List<Row>> _rowsByCategory = new(StringComparer.Ordinal);
    private CancellationTokenSource? _cts;
    private CategoryRow? _selectedCategory;

    public CleanPage()
    {
        InitializeComponent();
        CategoryList.ItemsSource = _categories;

        Loaded += async (s, e) => await ScanAsync();
        Unloaded += (s, e) => { _cts?.Cancel(); _cts?.Dispose(); _cts = null; };
    }

    private void OnSelectionChanged()
    {
        if (_selectedCategory != null) RefreshCategory(_selectedCategory);
        UpdateSelectionSummary();
    }

    // ------------------------------------------------------------------ scanning
    /// <summary>
    /// A single scan, then group by category. An earlier version ran a rollup
    /// pass and then re-walked the filesystem once per category clicked.
    /// </summary>
    private async System.Threading.Tasks.Task ScanAsync()
    {
        SetScanning(true);
        TxtScanState.Text = "Scanning…";

        _cts?.Cancel();
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;

        var progress = new Progress<(string CurrentTask, double Percent)>(p =>
        {
            TxtScanProgress.Text = p.CurrentTask;
            TxtScanState.Text = p.CurrentTask;
        });

        try
        {
            var summary = await WindowsScanner.RunScanAsync(progress, ct).ConfigureAwait(true);
            ct.ThrowIfCancellationRequested();

            _rowsByCategory.Clear();
            _categories.Clear();

            foreach (var item in summary.Items)
            {
                if (!_rowsByCategory.TryGetValue(item.Rule.Category, out var list))
                {
                    list = new List<Row>();
                    _rowsByCategory[item.Rule.Category] = list;
                }

                // Cleanable rows start ticked, matching the macOS default, but
                // each one stays individually deselectable.
                // Opt-in categories such as Old Windows Installations are never
                // ticked automatically: that is the whole point of them being
                // opt-in, since they remove a rollback path.
                var optIn = WindowsScanCatalog.IsOptInCategory(item.Rule.Category);
                list.Add(new Row
                {
                    Item = item,
                    Owner = this,
                    IsSelected = !item.IsBlocked && !optIn
                });
            }

            var previous = _selectedCategory?.Name;

            foreach (var category in WindowsScanCatalog.Categories)
            {
                _rowsByCategory.TryGetValue(category, out var rows);

                var entry = new CategoryRow
                {
                    Name = category,
                    Rows = rows ?? new List<Row>()
                };
                RefreshCategory(entry);
                _categories.Add(entry);
            }

            _selectedCategory = _categories.FirstOrDefault(c => c.Name == previous)
                                ?? _categories.FirstOrDefault(c => c.Name == WindowsScanCatalog.DefaultCategory)
                                ?? _categories.FirstOrDefault(c => c.Rows.Count > 0);

            CategoryList.SelectedItem = _selectedCategory;

            if (_selectedCategory == null)
            {
                ShowEmpty("Nothing to clean", "Your caches are already small.");
            }
            else
            {
                ShowCategory(_selectedCategory);
            }

            TxtScanState.Text = summary.TotalCleanableBytes > 0
                ? $"{WormFormat.Bytes(summary.TotalCleanableBytes)} reclaimable" +
                  (summary.TotalBlockedBytes > 0
                      ? $", {WormFormat.Bytes(summary.TotalBlockedBytes)} kept"
                      : string.Empty)
                : "Nothing to clean. Your caches are already small.";
        }
        catch (OperationCanceledException)
        {
            // Navigated away mid-scan.
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("CleanPage.ScanAsync", ex);
            ShowEmpty("Scan failed", ex.Message);
            TxtScanState.Text = "Scan failed.";
        }
        finally
        {
            SetScanning(false);
        }
    }

    private void ShowCategory(CategoryRow category)
    {
        _selectedCategory = category;
        TxtDetailTitle.Text = category.Name;

        var cleanable = category.Rows.Count(r => !r.IsBlocked);
        var kept = category.Rows.Count - cleanable;
        TxtDetailSummary.Text = category.Rows.Count == 0
            ? "Nothing found in this category."
            : $"{cleanable} cleanable, {kept} kept for safety.";

        ApplyFilter();
    }

    private void SetScanning(bool busy)
    {
        PanelScanning.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
        ScanProgress.Visibility = busy ? Visibility.Visible : Visibility.Collapsed;
        BtnRescan.IsEnabled = !busy;
        BtnSelectAll.IsEnabled = !busy;
        BtnClean.IsEnabled = !busy && _selectedCategory?.Rows.Any(r => r.IsSelected) == true;
    }

    // ---------------------------------------------------------------- categories
    private void RefreshCategory(CategoryRow category)
    {
        var cleanable = category.Rows.Where(r => !r.IsBlocked).ToList();
        var blocked = category.Rows.Count - cleanable.Count;

        long bytes = cleanable.Sum(r => r.Item.SizeBytes);
        int selected = cleanable.Count(r => r.IsSelected);

        category.FormattedSize = bytes > 0 ? WormFormat.Bytes(bytes) : string.Empty;

        category.Subtitle = category.Rows.Count switch
        {
            0 => "Nothing found",
            _ when cleanable.Count == 0 => $"{blocked} kept for safety",
            _ when selected == cleanable.Count => $"{cleanable.Count} selected",
            _ => $"{selected}/{cleanable.Count} selected"
        };
    }

    private void CategoryList_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (CategoryList.SelectedItem is not CategoryRow category) return;

        ShowCategory(category);
        UpdateSelectionSummary();
    }

    private void Tri_Changed(object sender, CheckChangedEventArgs e)
    {
        if (((FrameworkElement)sender).DataContext is not CategoryRow category) return;

        // Tri-state: a partial tick selects the whole category, matching the macOS
        // TriStateBox behaviour. The control already flipped its own state.
        bool want = e.IsChecked;

        var optIn = WindowsScanCatalog.IsOptInCategory(category.Name);

        foreach (var row in category.Rows)
        {
            if (row.IsBlocked) continue;
            // Selecting an opt-in category still only marks ordinary rows; the
            // rollback items must be ticked one by one.
            if (optIn) continue;
            row.IsSelected = want;
        }

        RefreshCategory(category);
        ApplyFilter();
        UpdateSelectionSummary();
    }

    // --------------------------------------------------------------------- detail
    private void ApplyFilter()
    {
        if (_selectedCategory == null)
        {
            ShowEmpty("Nothing to clean", "Run a scan to see what can be reclaimed.");
            return;
        }

        IEnumerable<Row> query = _selectedCategory.Rows;

        if (ChkShowBlocked.IsChecked != true)
            query = query.Where(r => !r.IsBlocked);

        var text = TxtFilter.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(text))
        {
            query = query.Where(r =>
                r.Label.Contains(text, StringComparison.OrdinalIgnoreCase) ||
                r.Item.Path.Contains(text, StringComparison.OrdinalIgnoreCase));
        }

        var rows = query
            .OrderByDescending(r => r.IsSelected)
            .ThenByDescending(r => r.Item.IsBlocked)
            .ThenByDescending(r => r.Item.SizeBytes)
            .ToList();

        ItemsGrid.ItemsSource = rows;

        if (rows.Count == 0)
        {
            ShowEmpty($"Nothing in {_selectedCategory.Name}",
                "No target matched the current filter.");
        }
        else
        {
            PanelEmpty.Visibility = Visibility.Collapsed;
            PanelList.Visibility = Visibility.Visible;
        }
    }

    private void ShowEmpty(string title, string body)
    {
        PanelEmpty.Visibility = Visibility.Visible;
        PanelList.Visibility = Visibility.Collapsed;
        TxtEmptyTitle.Text = title;
        TxtEmptyBody.Text = body;
    }

    private void TxtFilter_TextChanged(object sender, TextChangedEventArgs e) => ApplyFilter();

    private void ChkShowBlocked_Changed(object sender, RoutedEventArgs e) => ApplyFilter();

    private void BtnRescan_Click(object sender, RoutedEventArgs e) => _ = ScanAsync();

    private void BtnSelectAll_Click(object sender, RoutedEventArgs e)
    {
        if (_selectedCategory == null) return;

        var optIn = WindowsScanCatalog.IsOptInCategory(_selectedCategory.Name);
        bool anyUnselected = _selectedCategory.Rows
            .Any(r => !r.IsBlocked && !optIn && !r.IsSelected);

        foreach (var row in _selectedCategory.Rows)
        {
            if (row.IsBlocked || optIn) continue;
            row.IsSelected = anyUnselected;
        }

        RefreshCategory(_selectedCategory);
        ApplyFilter();
        UpdateSelectionSummary();
    }

    private void CmbDeleteMode_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        var permanent = CmbDeleteMode.SelectedIndex == 1;
        BtnClean.ToolTip = permanent
            ? "Permanent delete: these files cannot be restored."
            : "Files are moved to the Windows Recycle Bin.";
    }

    private void UpdateSelectionSummary()
    {
        var selected = _selectedCategory?.Rows.Where(r => r.IsSelected).ToList() ?? new();
        long bytes = selected.Sum(r => r.Item.SizeBytes);

        TxtSelectedTotal.Text = WormFormat.Bytes(bytes);
        BtnClean.IsEnabled = selected.Count > 0;
        BtnClean.Content = selected.Count == 0
            ? "Clean"
            : $"Clean {WormFormat.Bytes(bytes)}";
    }

    // ------------------------------------------------------------------ cleaning
    private async void BtnClean_Click(object sender, RoutedEventArgs e)
    {
        var category = _selectedCategory;
        var selected = category?.Rows.Where(r => r.IsSelected).ToList();
        if (category == null || selected == null || selected.Count == 0) return;

        var mode = CmbDeleteMode.SelectedIndex == 1 ? DeleteMode.Permanent : DeleteMode.RecycleBin;
        long bytes = selected.Sum(r => r.Item.SizeBytes);
        int blocked = selected.Count(r => r.IsBlocked);

        var confirm =
            $"About to clean {selected.Count} target{(selected.Count == 1 ? "" : "s")} " +
            $"({WormFormat.Bytes(bytes)}) from {category.Name}.\n\n" +
            (mode == DeleteMode.Permanent
                ? "PERMANENT DELETE. These files will NOT go to the Recycle Bin."
                : "Files will be moved to the Windows Recycle Bin and can be restored.") +
            (blocked > 0 ? $"\n\n{blocked} protected item(s) will be skipped." : string.Empty) +
            "\n\nProceed?";

        if (MessageBox.Show(confirm, "Confirm Clean", MessageBoxButton.YesNo,
                mode == DeleteMode.Permanent ? MessageBoxImage.Warning : MessageBoxImage.Question)
            != MessageBoxResult.Yes)
        {
            return;
        }

        BtnClean.IsEnabled = false;
        BtnRescan.IsEnabled = false;

        int cleaned = 0, failed = 0;

        try
        {
            foreach (var row in selected)
            {
                // Re-check the policy at delete time, not just at scan time:
                // the path may have been replaced while the list was on screen.
                var allowStaging = WindowsScanCatalog.IsOptInCategory(row.Item.Rule.Category);
                var verdict = WindowsSafetyPolicy.Evaluate(
                    row.Item.Path, probeLiveness: true, allowWindowsUpgradeStaging: allowStaging);
                if (verdict.IsBlocked) { failed++; continue; }

                if (await WindowsReclaimer.CleanTargetAsync(row.Item.Path, mode)) cleaned++;
                else failed++;
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("CleanPage.BtnClean_Click", ex);
            MessageBox.Show($"Cleaning stopped: {ex.Message}", "Worm",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }

        MessageBox.Show(
            failed == 0
                ? $"Cleaned {cleaned} target{(cleaned == 1 ? "" : "s")}."
                : $"Cleaned {cleaned}, skipped or failed {failed}. See the log for details.",
            "Worm", MessageBoxButton.OK, MessageBoxImage.Information);

        await ScanAsync();
    }
}
