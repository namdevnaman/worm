using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Threading;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Worm.Core;

namespace Worm.UI;

public partial class LeftoversPage : Page
{
    public sealed class TraceRow : INotifyPropertyChanged
    {
        private bool _isSelected;

        public OrphanTrace Trace { get; set; } = null!;
        public LeftoversPage? Owner { get; set; }

        public string Name => Trace.DisplayName;
        public long SizeBytes => Trace.SizeBytes;
        public string FormattedSize => WormFormat.Bytes(Trace.SizeBytes);
        public bool NeedsReview => Trace.NeedsReview;
        public string ReviewReason => Trace.ReviewReason;
        public string Meta => $"{OrphanLocationInfo.DisplayName(Trace.Location)} · {Trace.AgeDays}d old";

        public bool CanRemove
        {
            get
            {
                try { return WindowsOrphanDetector.CanRemove(Trace); }
                catch { return false; }
            }
        }

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                // A trace that cannot be removed must never appear ticked.
                if (!CanRemove) value = false;
                if (_isSelected == value) return;
                _isSelected = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(IsSelected)));
                Owner?.OnSelectionChanged();
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }

    public sealed class GroupRow
    {
        public string DisplayName { get; set; } = string.Empty;
        public List<TraceRow> Traces { get; set; } = new();
        public long TotalBytes => Traces.Sum(t => t.SizeBytes);
        public string FormattedSize => WormFormat.Bytes(TotalBytes);
        public int ReviewCount => Traces.Count(t => t.NeedsReview);
        public int SelectedCount => Traces.Count(t => t.IsSelected);
    }

    private sealed class LocationStat
    {
        public string Location { get; set; } = string.Empty;
        public int Count { get; set; }
        public string Size { get; set; } = string.Empty;
    }

    private readonly List<GroupRow> _groups = new();
    private readonly HashSet<string> _expanded = new(StringComparer.OrdinalIgnoreCase);
    private CancellationTokenSource? _cts;

    public LeftoversPage()
    {
        InitializeComponent();

        PanelLoading.Content = WormStates.Loading(
            "Worm is digging into leftover folders…",
            "Finding data left behind by apps you removed.");

        PanelEmpty.Content = WormStates.Empty(
            "No leftovers found",
            "Every app that has data on this PC still has its app installed.",
            positive: true);

        Loaded += async (s, e) => await ScanAsync();
        Unloaded += (s, e) => { _cts?.Cancel(); _cts?.Dispose(); _cts = null; };
    }

    public void OnSelectionChanged() => RebuildList();

    private async System.Threading.Tasks.Task ScanAsync()
    {
        PanelLoading.Visibility = Visibility.Visible;
        PanelEmpty.Visibility = Visibility.Collapsed;
        PanelList.Visibility = Visibility.Collapsed;
        BtnRescan.IsEnabled = false;

        _cts?.Cancel();
        _cts?.Dispose();
        _cts = new CancellationTokenSource();
        var ct = _cts.Token;

        try
        {
            // The walk measures every trace, so it must stay off the UI thread.
            var groups = await Task.Run(() => WindowsOrphanDetector.DetectOrphans(), ct)
                                .ConfigureAwait(true);
            ct.ThrowIfCancellationRequested();

            _groups.Clear();
            foreach (var g in groups)
            {
                _groups.Add(new GroupRow
                {
                    DisplayName = g.DisplayName,
                    Traces = g.Traces
                        .Select(t => new TraceRow { Trace = t, Owner = this })
                        .ToList()
                });
            }

            RebuildList();

            PanelEmpty.Visibility = _groups.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
            PanelList.Visibility = _groups.Count == 0 ? Visibility.Collapsed : Visibility.Visible;

            UpdateStats();
        }
        catch (OperationCanceledException)
        {
            // Navigated away.
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("LeftoversPage.ScanAsync", ex);
            MessageBox.Show($"Leftover scan failed: {ex.Message}", "Worm",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            PanelLoading.Visibility = Visibility.Collapsed;
            BtnRescan.IsEnabled = true;
        }
    }

    private IEnumerable<GroupRow> VisibleGroups()
    {
        IEnumerable<GroupRow> query = _groups;

        if (ChkReviewOnly.IsChecked == true)
            query = query.Where(g => g.ReviewCount > 0);

        var text = TxtFilter.Text?.Trim().ToLowerInvariant();
        if (!string.IsNullOrEmpty(text))
        {
            query = query.Where(g =>
                g.DisplayName.Contains(text, StringComparison.OrdinalIgnoreCase) ||
                g.Traces.Any(t => t.Name.Contains(text, StringComparison.OrdinalIgnoreCase) ||
                                  t.Trace.Path.Contains(text, StringComparison.OrdinalIgnoreCase)));
        }

        return query.OrderByDescending(g => g.TotalBytes);
    }

    /// <summary>
    /// Rebuilds the list imperatively. A grouped tree with expand/collapse and
    /// live tri-state selection is far simpler to drive in code than through
    /// nested templates, and it keeps the selection state in one place.
    /// </summary>
    private void RebuildList()
    {
        GroupHost.Children.Clear();

        foreach (var group in VisibleGroups())
        {
            var expanded = _expanded.Contains(group.DisplayName);

            // ---- group header ----
            var header = new Grid { Margin = new Thickness(0, 0, 0, 2) };
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

            var allSelected = group.Traces.Any(t => t.CanRemove) &&
                              group.Traces.Where(t => t.CanRemove).All(t => t.IsSelected);
            var someSelected = group.Traces.Any(t => t.IsSelected);

            var box = new CheckBox
            {
                IsChecked = allSelected ? true : (someSelected ? null : false),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 8, 0),
                IsEnabled = group.Traces.Any(t => t.CanRemove)
            };
            var captured = group;
            box.Checked += (s, e) => SetGroup(captured, true);
            box.Unchecked += (s, e) => SetGroup(captured, false);

            var chevron = new TextBlock
            {
                Text = expanded ? "▾" : "▸",
                FontSize = 10,
                Foreground = (Brush)FindResource("InkTertiary"),
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(0, 0, 8, 0)
            };

            var title = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
            title.Children.Add(new TextBlock
            {
                Text = group.DisplayName,
                FontSize = 12,
                FontWeight = expanded ? FontWeights.SemiBold : FontWeights.Normal,
                Foreground = (Brush)FindResource("Ink")
            });
            title.Children.Add(new TextBlock
            {
                Text = group.ReviewCount > 0
                    ? $"{group.Traces.Count} items · {group.ReviewCount} need review"
                    : $"{group.Traces.Count} items",
                FontSize = 9,
                Foreground = (Brush)FindResource("InkTertiary")
            });

            var size = new TextBlock
            {
                Text = group.FormattedSize,
                FontSize = 11,
                FontFamily = (FontFamily)FindResource("FontMono"),
                Foreground = (Brush)FindResource("InkSecondary"),
                VerticalAlignment = VerticalAlignment.Center
            };

            Grid.SetColumn(box, 0);
            Grid.SetColumn(chevron, 1);
            Grid.SetColumn(title, 1);
            Grid.SetColumn(size, 2);
            Grid.SetColumnSpan(title, 1);

            header.Children.Add(box);
            header.Children.Add(chevron);
            header.Children.Add(title);
            header.Children.Add(size);

            var headerBorder = new Border
            {
                Background = (Brush)FindResource("LoamSurface"),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(10, 6, 10, 6),
                Child = header,
                Cursor = System.Windows.Input.Cursors.Hand
            };
            WormMotion.AttachHover(headerBorder);
            var headerGroup = group;
            headerBorder.MouseLeftButtonUp += (s, e) =>
            {
                if (_expanded.Contains(headerGroup.DisplayName)) _expanded.Remove(headerGroup.DisplayName);
                else _expanded.Add(headerGroup.DisplayName);
                RebuildList();
            };

            GroupHost.Children.Add(headerBorder);

            if (!expanded) continue;

            // ---- traces ----
            foreach (var trace in group.Traces.OrderByDescending(t => t.SizeBytes))
            {
                var row = new Grid { Margin = new Thickness(31, 0, 10, 1) };
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
                row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

                var traceBox = new CheckBox
                {
                    IsChecked = trace.IsSelected,
                    IsEnabled = trace.CanRemove,
                    Opacity = trace.CanRemove ? 1.0 : 0.4,
                    VerticalAlignment = VerticalAlignment.Center,
                    Margin = new Thickness(0, 0, 8, 0)
                };
                var capturedTrace = trace;
                traceBox.Checked += (s, e) => capturedTrace.IsSelected = true;
                traceBox.Unchecked += (s, e) => capturedTrace.IsSelected = false;

                var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
                text.Children.Add(new TextBlock
                {
                    Text = trace.Name,
                    FontSize = 11,
                    Foreground = trace.CanRemove
                        ? (Brush)FindResource("Ink")
                        : (Brush)FindResource("InkTertiary"),
                    TextTrimming = TextTrimming.CharacterEllipsis
                });

                var meta = new TextBlock
                {
                    Text = trace.Meta + (trace.NeedsReview ? " · needs review" : string.Empty),
                    FontSize = 9,
                    Foreground = trace.NeedsReview
                        ? (Brush)FindResource("Warn")
                        : (Brush)FindResource("InkTertiary")
                };
                if (trace.NeedsReview) meta.ToolTip = trace.ReviewReason;
                text.Children.Add(meta);

                var tSize = new TextBlock
                {
                    Text = trace.FormattedSize,
                    FontSize = 10,
                    FontFamily = (FontFamily)FindResource("FontMono"),
                    Foreground = (Brush)FindResource("InkTertiary"),
                    VerticalAlignment = VerticalAlignment.Center
                };

                Grid.SetColumn(traceBox, 0);
                Grid.SetColumn(text, 1);
                Grid.SetColumn(tSize, 2);

                row.Children.Add(traceBox);
                row.Children.Add(text);
                row.Children.Add(tSize);

                var traceBorder = new Border
                {
                    Background = trace.IsSelected
                        ? (Brush)FindResource("LoamSurfaceRaised")
                        : Brushes.Transparent,
                    CornerRadius = new CornerRadius(6),
                    Padding = new Thickness(10, 4, 10, 4),
                    Child = row
                };
                WormMotion.AttachHover(traceBorder);
                GroupHost.Children.Add(traceBorder);
            }
        }
    }

    private void SetGroup(GroupRow group, bool selected)
    {
        foreach (var trace in group.Traces)
        {
            if (trace.CanRemove) trace.IsSelected = selected;
        }
        RebuildList();
        UpdateStats();
    }

    private void UpdateStats()
    {
        var all = _groups.SelectMany(g => g.Traces).ToList();
        var selected = all.Where(t => t.IsSelected).ToList();

        StatItems.Text = selected.Count.ToString();
        StatSize.Text = WormFormat.Bytes(selected.Sum(t => t.SizeBytes));
        StatReview.Text = selected.Count(t => t.NeedsReview).ToString();

        var blocked = selected.Count(t => !t.CanRemove);
        StatBlocked.Text = blocked.ToString();

        TxtNothingSelected.Visibility = selected.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        if (selected.Count > 0)
            TxtNothingSelected.Text = "Some selected items hold data that may be yours. Review them before removing.";

        BtnRemove.IsEnabled = selected.Count > 0 && blocked < selected.Count;
        BtnRemove.Content = selected.Count == 0 ? "Remove Selected" : $"Remove {selected.Count} Item(s)";

        // Per-location rollup
        var byLocation = selected
            .GroupBy(t => OrphanLocationInfo.DisplayName(t.Trace.Location))
            .Select(g => new LocationStat
            {
                Location = g.Key,
                Count = g.Count(),
                Size = WormFormat.Bytes(g.Sum(t => t.SizeBytes))
            })
            .OrderByDescending(s => s.Size)
            .ToList();

        LocationList.ItemsSource = byLocation;
        TxtByLocation.Visibility = byLocation.Count == 0 ? Visibility.Collapsed : Visibility.Visible;

        if (blocked > 0)
        {
            BlockedWarning.Visibility = Visibility.Visible;
            TxtBlockedWarning.Text =
                $"{blocked} selected item(s) cannot be removed by this app and will be skipped.";
        }
        else
        {
            BlockedWarning.Visibility = Visibility.Collapsed;
        }
    }

    // ------------------------------------------------------------------ actions
    private void BtnRescan_Click(object sender, RoutedEventArgs e)
    {
        _expanded.Clear();
        _ = ScanAsync();
    }

    private void BtnSelectAll_Click(object sender, RoutedEventArgs e)
    {
        var anyUnselected = VisibleGroups()
            .SelectMany(g => g.Traces)
            .Any(t => t.CanRemove && !t.IsSelected);

        foreach (var trace in VisibleGroups().SelectMany(g => g.Traces))
        {
            if (trace.CanRemove) trace.IsSelected = anyUnselected;
        }

        RebuildList();
        UpdateStats();
    }

    private void TxtFilter_TextChanged(object sender, TextChangedEventArgs e) => RebuildList();

    private void ChkReviewOnly_Changed(object sender, RoutedEventArgs e) => RebuildList();

    private async void BtnRemove_Click(object sender, RoutedEventArgs e)
    {
        var selected = _groups.SelectMany(g => g.Traces).Where(t => t.IsSelected).ToList();
        if (selected.Count == 0) return;

        long bytes = selected.Sum(t => t.SizeBytes);
        int review = selected.Count(t => t.NeedsReview);

        var confirm =
            $"Move {selected.Count} leftover folder{(selected.Count == 1 ? "" : "s")} " +
            $"({WormFormat.Bytes(bytes)}) to the Recycle Bin?\n\n" +
            "Only the folders you ticked will be touched." +
            (review > 0
                ? $"\n\n{review} of them may hold your own data. Those were marked " +
                  "\"needs review\" for a reason."
                : string.Empty) +
            "\n\nProceed?";

        if (MessageBox.Show(confirm, "Confirm Leftover Removal",
                MessageBoxButton.YesNo, MessageBoxImage.Question) != MessageBoxResult.Yes)
        {
            return;
        }

        BtnRemove.IsEnabled = false;
        BtnRescan.IsEnabled = false;

        int cleaned = 0, failed = 0;

        try
        {
            foreach (var trace in selected)
            {
                // Re-verify at delete time; the folder may have changed.
                var verdict = WindowsSafetyPolicy.Evaluate(trace.Trace.Path);
                if (verdict.IsBlocked) { failed++; continue; }

                if (await WindowsReclaimer.CleanTargetAsync(trace.Trace.Path, DeleteMode.RecycleBin))
                    cleaned++;
                else
                    failed++;
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("LeftoversPage.BtnRemove_Click", ex);
            MessageBox.Show($"Removal stopped: {ex.Message}", "Worm",
                MessageBoxButton.OK, MessageBoxImage.Error);
        }

        MessageBox.Show(
            failed == 0
                ? $"Removed {cleaned} folder{(cleaned == 1 ? "" : "s")}."
                : $"Removed {cleaned}, skipped or failed {failed}. See the log for details.",
            "Worm", MessageBoxButton.OK, MessageBoxImage.Information);

        _expanded.Clear();
        await ScanAsync();
    }
}
