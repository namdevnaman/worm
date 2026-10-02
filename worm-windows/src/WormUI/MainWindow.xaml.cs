using System;
using System.Windows;
using ModernWpf.Controls;
using ModernWpf.Controls.Primitives;
using Worm.Core;
using System.Windows.Controls.Primitives;
using System.Windows.Input;

namespace Worm.UI;

public partial class MainWindow : Window
{
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMSBT_TRANSIENTWINDOW = 3; // Acrylic / frosted glass

    private bool _quitting;
    private TrayPanel? _trayPanel;

    /// <summary>
    /// Bisect switch. Set WORM_SAFE=1 in the environment to strip every optional
    /// visual layer: the ModernWpf custom window style, the acrylic backdrop and
    /// high-quality image scaling. Two of those create layered/transparent
    /// surfaces, and text rendering on those surfaces is a documented source of
    /// OutOfMemoryException in FullTextLine.DrawTextLine. If Worm starts with
    /// WORM_SAFE=1 but not without it, the cause is one of those layers rather
    /// than the app's logic.
    /// </summary>
    internal static bool SafeMode
    {
        get
        {
            var v = Environment.GetEnvironmentVariable("WORM_SAFE");
            return !string.IsNullOrWhiteSpace(v) && v != "0";
        }
    }

    public MainWindow()
    {
        try
        {
            InitializeComponent();
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("MainWindow.InitializeComponent", ex);
            throw;
        }

        if (SafeMode)
        {
            try
            {
                WindowHelper.SetUseModernWindowStyle(this, false);
                Background = new System.Windows.Media.SolidColorBrush(
                    System.Windows.Media.Color.FromRgb(0x15, 0x13, 0x11));
                WindowsCrashLog.Write("MainWindow.SafeMode", null);
            }
            catch (Exception ex)
            {
                WindowsCrashLog.Write("MainWindow.SafeMode", ex);
            }
        }

        Loaded += MainWindow_Loaded;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        if (SafeMode) return;

        try
        {
            var hwnd = new System.Windows.Interop.WindowInteropHelper(this).Handle;
            int backdropType = DWMSBT_TRANSIENTWINDOW;
            DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, ref backdropType, sizeof(int));
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("MainWindow.OnSourceInitialized.Dwm", ex);
        }
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        RestorePaneWidth();

        // NavigationView 0.9.6 exposes IsPaneOpen but no pane open/close events, so
        // the dependency property is watched directly. Collapsing the pane has to
        // hide the gripper, otherwise it would float over the toggle button with
        // no edge underneath it.
        System.ComponentModel.DependencyPropertyDescriptor
            .FromProperty(NavigationView.IsPaneOpenProperty, typeof(NavigationView))
            .AddValueChanged(NavView, (_, _) => UpdateGripperPosition());

        UpdateGripperPosition();

        if (NavView.MenuItems.Count > 0)
        {
            NavView.SelectedItem = NavView.MenuItems[0];
        }
    }

    /// <summary>
    /// Preset pane widths, cycled by the header button and by double-clicking the
    /// gripper. ModernWpfUI's NavigationView exposes OpenPaneLength but no drag
    /// handle, so the gripper overlay and this button are the two resize paths.
    /// </summary>
    private static readonly double[] PaneWidths = { 232, 300, 180 };

    /// <summary>Drag limits, in device-independent pixels.</summary>
    private const double PaneWidthMin = 160;
    private const double PaneWidthMax = 420;

    private int _paneWidthIndex;

    private void BtnPaneWidth_Click(object sender, RoutedEventArgs e)
    {
        _paneWidthIndex = (_paneWidthIndex + 1) % PaneWidths.Length;
        NavView.OpenPaneLength = PaneWidths[_paneWidthIndex];

        UpdateGripperPosition();
        SavePaneWidth();
    }

    /// <summary>
    /// Drives the pane width from the gripper. The gripper is repositioned on every
    /// delta rather than relying on a binding, because the pane edge lives inside
    /// NavigationView's private template.
    /// </summary>
    private void PaneGripper_DragDelta(object sender, DragDeltaEventArgs e)
    {
        if (!NavView.IsPaneOpen) return;

        var width = NavView.OpenPaneLength + e.HorizontalChange;
        NavView.OpenPaneLength = ClampPaneWidth(width);

        UpdateGripperPosition();
    }

    /// <summary>Persists the width once, on release, not on every delta.</summary>
    private void PaneGripper_DragCompleted(object sender, DragCompletedEventArgs e)
    {
        SyncPaneWidthIndex(NavView.OpenPaneLength);
        SavePaneWidth();
    }

    /// <summary>Double-clicking the gripper cycles the presets.</summary>
    private void PaneGripper_MouseDoubleClick(object sender, MouseButtonEventArgs e)
    {
        BtnPaneWidth_Click(sender, e);
        e.Handled = true;
    }

    private static double ClampPaneWidth(double width)
        => Math.Min(PaneWidthMax, Math.Max(PaneWidthMin, width));

    /// <summary>
    /// Parks the gripper on the pane's right edge. When the pane is collapsed there
    /// is no edge to grab, so the gripper hides rather than floating over the
    /// toggle button.
    /// </summary>
    private void UpdateGripperPosition()
    {
        if (PaneGripper == null || NavView == null) return;

        if (!NavView.IsPaneOpen)
        {
            PaneGripper.Visibility = Visibility.Hidden;
            return;
        }

        PaneGripper.Visibility = Visibility.Visible;

        // Straddle the edge so the whole 9px band is grabbable, not just the half
        // that overlaps the pane.
        PaneGripper.Margin = new Thickness(NavView.OpenPaneLength - PaneGripper.Width / 2, 0, 0, 0);
    }

    private void SavePaneWidth()
    {
        try
        {
            var config = WindowsPaths.ConfigDir;
            System.IO.Directory.CreateDirectory(config);
            System.IO.File.WriteAllText(
                System.IO.Path.Combine(config, "pane-width.txt"),
                NavView.OpenPaneLength.ToString(System.Globalization.CultureInfo.InvariantCulture));
        }
        catch { /* preference is cosmetic; never block on it */ }
    }

    private void RestorePaneWidth()
    {
        try
        {
            var file = System.IO.Path.Combine(WindowsPaths.ConfigDir, "pane-width.txt");
            if (!System.IO.File.Exists(file)) return;

            var raw = System.IO.File.ReadAllText(file).Trim();
            if (raw.Length == 0) return;

            if (!double.TryParse(raw, System.Globalization.NumberStyles.Float,
                    System.Globalization.CultureInfo.InvariantCulture, out var value)) return;

            if (value >= PaneWidthMin && value <= PaneWidthMax)
            {
                // Current format: the exact width, stored on drag release.
                NavView.OpenPaneLength = ClampPaneWidth(value);
                SyncPaneWidthIndex(NavView.OpenPaneLength);
            }
            else if (value >= 0 && value < PaneWidths.Length)
            {
                // Builds before the gripper stored a preset index of 0, 1 or 2.
                // Those parse as valid doubles, so the width range is what
                // disambiguates them - no user ever wants a 2px pane.
                _paneWidthIndex = (int)value;
                NavView.OpenPaneLength = PaneWidths[_paneWidthIndex];
            }

            UpdateGripperPosition();
        }
        catch { }
    }

    /// <summary>
    /// Keeps the cycle button pointing at the nearest preset, so dragging to a new
    /// width and then pressing the button advances from a sensible place.
    /// </summary>
    private void SyncPaneWidthIndex(double width)
    {
        var best = 0;
        var bestDistance = double.MaxValue;

        for (int i = 0; i < PaneWidths.Length; i++)
        {
            var distance = Math.Abs(PaneWidths[i] - width);
            if (distance >= bestDistance) continue;
            bestDistance = distance;
            best = i;
        }

        _paneWidthIndex = best;
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        try
        {
            if (args.IsSettingsSelected)
            {
                Navigate(new SettingsPage());
                return;
            }

            if (args.SelectedItem is NavigationViewItem item)
            {
                switch (item.Tag?.ToString())
                {
                    case "Clean":     Navigate(new CleanPage()); break;
                    case "Leftovers": Navigate(new LeftoversPage()); break;
                    case "Apps":      Navigate(new AppsPage()); break;
                    case "Disk":      Navigate(new DiskPage()); break;
                    case "Status":    Navigate(new StatusPage()); break;
                }
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("NavView_SelectionChanged", ex);
        }
    }

    private void Navigate(System.Windows.Controls.Page page)
    {
        TransitionOverlay.Visibility = Visibility.Visible;
        var timer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(160)
        };
        timer.Tick += (s, e) =>
        {
            timer.Stop();
            try
            {
                ContentFrame.Navigate(page);

                // Fade and rise the new page in, matching the macOS tab transition.
                if (page != null) WormMotion.AnimatePageIn(page);
            }
            catch (Exception ex)
            {
                WindowsCrashLog.Write("Navigate", ex);
            }
            finally
            {
                TransitionOverlay.Visibility = Visibility.Collapsed;
            }
        };
        timer.Start();
    }

    private void SelectTab(string tag)
    {
        if (tag == "Settings")
        {
            NavView.SelectedItem = NavView.SettingsItem;
            return;
        }

        foreach (var item in NavView.MenuItems)
        {
            if (item is NavigationViewItem nav && nav.Tag?.ToString() == tag)
            {
                NavView.SelectedItem = nav;
                return;
            }
        }
    }

    private void TrayIcon_TrayLeftMouseDown(object sender, RoutedEventArgs e)
    {
        // Left click toggles the live panel, matching the macOS menu bar item.
        if (_trayPanel is { IsVisible: true })
        {
            _trayPanel.Hide();
            return;
        }

        ShowAndActivate();
        ShowTrayPanel();
    }

    private void ShowTrayPanel()
    {
        try
        {
            if (_trayPanel == null)
            {
                _trayPanel = new TrayPanel
                {
                    Owner = this
                };
                _trayPanel.QuickScanRequested += (_, _) => { _trayPanel?.Hide(); SelectTab("Clean"); };
                _trayPanel.OpenStatusRequested += (_, _) => { _trayPanel?.Hide(); SelectTab("Status"); };
                _trayPanel.OpenSettingsRequested += (_, _) => { _trayPanel?.Hide(); SelectTab("Settings"); };
                _trayPanel.ExitRequested += (_, _) => ExitApp_Click(this, new RoutedEventArgs());
            }

            // Virtual screen covers multi-monitor setups, which SystemInformation
            // would not without a WinForms reference this project does not carry.
            var bounds = SystemParameters.WorkArea;
            _trayPanel.ShowNear(new Point(
                bounds.Left + bounds.Width - 8,
                bounds.Top + bounds.Height));
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("MainWindow.ShowTrayPanel", ex);
        }
    }

    private void OpenWindow_Click(object sender, RoutedEventArgs e)
        => ShowAndActivate();

    private void QuickScan_Click(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
        SelectTab("Clean");
    }

    private void TrayStatus_Click(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
        SelectTab("Status");
    }

    private void CleanScreen_Click(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
        CleanScreenMode.Show();
    }

    private void ExitApp_Click(object sender, RoutedEventArgs e)
    {
        _quitting = true;
        try { TrayIcon.Dispose(); }
        catch (Exception ex) { WindowsCrashLog.Write("ExitApp.TrayIcon.Dispose", ex); }
        Application.Current.Shutdown();
    }

    private void ShowAndActivate()
    {
        Show();
        WindowState = WindowState.Normal;
        Activate();
    }

    protected override void OnClosing(System.ComponentModel.CancelEventArgs e)
    {
        if (_quitting)
        {
            _trayPanel?.Close();
            return;
        }

        // Minimise to tray on close, but never trap the user: if there is no tray
        // icon to come back through (RDP, Server Core, or icon creation failed),
        // the window must close normally or the app becomes unkillable.
        if (_quitting) return;

        try
        {
            if (TrayIcon.IsCreated)
            {
                e.Cancel = true;
                Hide();
                return;
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("OnClosing.TrayIcon", ex);
        }

        _quitting = true;
    }
}
