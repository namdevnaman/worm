using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Threading;
using Worm.Core;

namespace Worm.UI;

/// <summary>
/// The Windows counterpart of the macOS menu bar panel: a small always-current
/// readout that stays available when the main window is closed to the tray.
///
/// Built in code rather than XAML because every value is refreshed on a timer,
/// and doing it here keeps the update path in one place instead of scattering
/// bindings across controls that would each need invalidating.
/// </summary>
public sealed class TrayPanel : Window
{
    /// <summary>A value/label pair that can be updated without rebuilding.</summary>
    private sealed class Metric
    {
        public TextBlock Value { get; } = new();
        public TextBlock Label { get; } = new();

        public Metric()
        {
            Value.FontSize = 15;
            Value.FontWeight = FontWeights.SemiBold;
            Value.FontFamily = new FontFamily("Consolas");
            Value.Foreground = Brush(Ivory);
            ApplyTextOptions(Value);

            Label.FontSize = 8;
            Label.Foreground = Brush(Tertiary);
            ApplyTextOptions(Label);
        }

        public FrameworkElement View => new StackPanel { Children = { Value, Label } };

        public void Set(string value, string label)
        {
            Value.Text = value;
            Label.Text = label;
        }
    }

    private const byte IvoryR = 0xF2, IvoryG = 0xED, IvoryB = 0xE8;
    private const byte TertiaryR = 0x85, TertiaryG = 0x7D, TertiaryB = 0x75;

    private static readonly Color Ivory = Color.FromRgb(IvoryR, IvoryG, IvoryB);
    private static readonly Color Tertiary = Color.FromRgb(TertiaryR, TertiaryG, TertiaryB);

    private static SolidColorBrush Brush(Color c) => new(c);

    /// <summary>
    /// The Display formatting mode is required app-wide; applying it to generated
    /// controls keeps this programmatic panel consistent with the XAML screens.
    /// </summary>
    private static void ApplyTextOptions(TextBlock t)
    {
        TextOptions.SetTextFormattingMode(t, TextFormattingMode.Display);
        TextOptions.SetTextRenderingMode(t, TextRenderingMode.ClearType);
    }

    private readonly DispatcherTimer _timer;
    private readonly Metric _cpu = new();
    private readonly Metric _memory = new();
    private readonly Metric _disk = new();
    private readonly Metric _reclaimed = new();
    private readonly Metric _uptime = new();

    public event EventHandler? QuickScanRequested;
    public event EventHandler? OpenStatusRequested;
    public event EventHandler? OpenSettingsRequested;
    public event EventHandler? ExitRequested;

    public TrayPanel()
    {
        Width = 272;
        SizeToContent = SizeToContent.Height;
        WindowStyle = WindowStyle.None;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        ResizeMode = ResizeMode.NoResize;
        Topmost = true;

        var panel = new StackPanel { Margin = new Thickness(14) };
        var root = new Border
        {
            CornerRadius = new CornerRadius(12),
            Margin = new Thickness(6),
            Background = Brush(Color.FromRgb(0x20, 0x1D, 0x1A)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x22, 0xFF, 0xFF, 0xFF)),
            BorderThickness = new Thickness(1),
            Child = panel
        };
        Content = root;

        panel.Children.Add(Header());
        panel.Children.Add(Divider());

        var grid = new Grid();
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        grid.ColumnDefinitions.Add(new ColumnDefinition());
        for (int i = 0; i < 3; i++) grid.RowDefinitions.Add(new RowDefinition());

        AddMetric(grid, 0, 0, _cpu);
        AddMetric(grid, 0, 1, _memory);
        AddMetric(grid, 1, 0, _disk);
        AddMetric(grid, 1, 1, _reclaimed);
        AddMetric(grid, 2, 0, _uptime);

        panel.Children.Add(grid);
        panel.Children.Add(Divider());

        panel.Children.Add(Action("Quick scan", () => QuickScanRequested?.Invoke(this, EventArgs.Empty)));
        panel.Children.Add(Action("Hardware status", () => OpenStatusRequested?.Invoke(this, EventArgs.Empty)));
        panel.Children.Add(Action("Settings", () => OpenSettingsRequested?.Invoke(this, EventArgs.Empty)));
        panel.Children.Add(Action("Exit", () => ExitRequested?.Invoke(this, EventArgs.Empty)));

        _timer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _timer.Tick += (s, e) => Refresh();

        Loaded += (s, e) => { Refresh(); _timer.Start(); };
        Closed += (s, e) => _timer.Stop();
    }

    private static FrameworkElement Header()
    {
        var row = new StackPanel { Orientation = Orientation.Horizontal };

        row.Children.Add(new Border
        {
            Width = 22,
            Height = 22,
            CornerRadius = new CornerRadius(6),
            Background = Brush(Color.FromRgb(0x2A, 0x26, 0x22)),
            Child = new TextBlock
            {
                Text = "W",
                FontSize = 12,
                FontWeight = FontWeights.Bold,
                Foreground = Brush(Color.FromRgb(0xC2, 0x6B, 0x47)),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center
            }
        });

        row.Children.Add(new TextBlock
        {
            Text = "Worm",
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brush(Ivory),
            Margin = new Thickness(9, 0, 0, 0),
            VerticalAlignment = VerticalAlignment.Center
        });

        return row;
    }

    private static void AddMetric(Grid grid, int row, int col, Metric metric)
    {
        var view = metric.View;
        view.Margin = new Thickness(0, 4, 8, 4);
        Grid.SetRow(view, row);
        Grid.SetColumn(view, col);
        grid.Children.Add(view);
    }

    private static Border Divider() => new()
    {
        Height = 1,
        Background = new SolidColorBrush(Color.FromArgb(0x1C, 0xFF, 0xFF, 0xFF)),
        Margin = new Thickness(0, 10, 0, 6)
    };

    private static Button Action(string label, Action onClick)
    {
        var content = new TextBlock
        {
            Text = label,
            FontSize = 11,
            Foreground = Brush(Ivory)
        };
        ApplyTextOptions(content);

        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.BackgroundProperty, Brushes.Transparent);
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(8));
        border.SetValue(Border.PaddingProperty, new Thickness(8, 6, 8, 6));

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.ContentProperty, content);
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Left);
        border.AppendChild(presenter);

        var template = new ControlTemplate(typeof(Button)) { VisualTree = border };

        // Name the border first so the trigger below can target it.
        border.Name = "Bd";

        var hover = new Trigger
        {
            Property = UIElement.IsMouseOverProperty,
            Value = true
        };
        hover.Setters.Add(new Setter(Border.BackgroundProperty,
            new SolidColorBrush(Color.FromArgb(0x22, 0xFF, 0xFF, 0xFF))));
        template.Triggers.Add(hover);

        var button = new Button
        {
            Content = label,
            Template = template,
            Margin = new Thickness(0, 1, 0, 1),
            Cursor = Cursors.Hand,
            FocusVisualStyle = null,
            HorizontalContentAlignment = HorizontalAlignment.Left
        };

        button.Click += (s, e) => onClick();
        return button;
    }

    /// <summary>Anchors the panel above the tray icon that opened it.</summary>
    public void ShowNear(Point screenPoint)
    {
        Refresh();

        // SizeToContent needs a layout pass before Height is meaningful.
        Measure(new Size(Width, double.PositiveInfinity));
        var height = DesiredSize.Height;

        Left = Math.Max(8, screenPoint.X - Width);
        Top = Math.Max(8, screenPoint.Y - height - 10);

        Show();
        Activate();
    }

    private void Refresh()
    {
        try
        {
            var snap = WindowsHardwareSampler.Sample();

            _cpu.Set($"{snap.CpuUsagePercent:0}%", "CPU");
            _memory.Set($"{snap.RamUsagePercent:0}%", "MEMORY");
            _disk.Set(WormFormat.Bytes(snap.DiskFreeBytes), "DISK FREE");
            _reclaimed.Set(WormFormat.Bytes(ReadReclaimed()), "RECLAIMED");
            _uptime.Set(WormFormat.Uptime(TimeSpan.FromMilliseconds(Environment.TickCount64)), "UPTIME");
        }
        catch
        {
            // A tray readout must never throw into the dispatcher.
        }
    }

    /// <summary>
    /// Sums every OK entry in the audit log. Reading it back rather than keeping a
    /// counter in memory means "reclaimed" only ever reports bytes that were
    /// actually removed, and it survives a restart.
    /// </summary>
    private static long ReadReclaimed()
    {
        try
        {
            long total = 0;
            foreach (var entry in WindowsAuditLog.Recent(5000))
            {
                if (entry.Status == "OK") total += entry.Bytes;
            }
            return total;
        }
        catch { return 0; }
    }
}
