using System;
using System.Windows;
using ModernWpf.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class MainWindow : Window
{
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMSBT_TRANSIENTWINDOW = 3; // Acrylic / frosted glass

    private bool _quitting;

    public MainWindow()
    {
        try
        {
            InitializeComponent();
        }
        catch (Exception ex)
        {
            // XAML/theme load failure: record it, because otherwise the app just vanishes.
            WindowsCrashLog.Write("MainWindow.InitializeComponent", ex);
            throw;
        }

        Loaded += MainWindow_Loaded;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
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
        // Default to Clean tab
        if (NavView.MenuItems.Count > 0)
        {
            NavView.SelectedItem = NavView.MenuItems[0];
        }
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        try
        {
            if (args.IsSettingsSelected)
            {
                NavigateWithAnimation(new SettingsPage());
                return;
            }

            if (args.SelectedItem is NavigationViewItem item)
            {
                switch (item.Tag?.ToString())
                {
                    case "Clean":
                        NavigateWithAnimation(new CleanPage());
                        break;
                    case "Leftovers":
                        NavigateWithAnimation(new LeftoversPage());
                        break;
                    case "Status":
                        NavigateWithAnimation(new StatusPage());
                        break;
                }
            }
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("NavView_SelectionChanged", ex);
        }
    }

    private void NavigateWithAnimation(System.Windows.Controls.Page page)
    {
        TransitionOverlay.Visibility = Visibility.Visible;
        var timer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(200)
        };
        timer.Tick += (s, e) =>
        {
            timer.Stop();
            try
            {
                ContentFrame.Navigate(page);
            }
            catch (Exception ex)
            {
                WindowsCrashLog.Write("NavigateWithAnimation", ex);
            }
            finally
            {
                TransitionOverlay.Visibility = Visibility.Collapsed;
            }
        };
        timer.Start();
    }

    private void TrayIcon_TrayLeftMouseDown(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
    }

    private void OpenWindow_Click(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
    }

    private void QuickClean_Click(object sender, RoutedEventArgs e)
    {
        ShowAndActivate();
        if (NavView.MenuItems.Count > 0)
        {
            NavView.SelectedItem = NavView.MenuItems[0];
        }
    }

    private void ExitApp_Click(object sender, RoutedEventArgs e)
    {
        _quitting = true;
        try
        {
            TrayIcon.Dispose();
        }
        catch (Exception ex)
        {
            WindowsCrashLog.Write("ExitApp.TrayIcon.Dispose", ex);
        }
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
        // Minimise to tray on close -- but never trap the user: if there is no tray
        // icon to come back through (e.g. RDP/Server Core, or icon creation failed),
        // the window must close normally or the app becomes unkillable.
        if (_quitting)
            return;

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
