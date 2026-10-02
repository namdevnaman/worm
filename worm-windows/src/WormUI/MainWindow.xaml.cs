using System;
using System.Windows;
using ModernWpf.Controls;

namespace Worm.UI;

public partial class MainWindow : Window
{
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DWMWA_SYSTEMBACKDROP_TYPE = 38;
    private const int DWMSBT_TRANSIENTWINDOW = 3; // Acrylic / frosted glass

    public MainWindow()
    {
        InitializeComponent();
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
        catch { }
    }

    private void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        // Default to Clean tab
        NavView.SelectedItem = NavView.MenuItems[0];
    }

    private void NavView_SelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
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

    private void NavigateWithAnimation(object page)
    {
        TransitionOverlay.Visibility = Visibility.Visible;
        var timer = new System.Windows.Threading.DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(200)
        };
        timer.Tick += (s, e) =>
        {
            timer.Stop();
            ContentFrame.Navigate(page);
            TransitionOverlay.Visibility = Visibility.Collapsed;
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
        NavView.SelectedItem = NavView.MenuItems[0];
    }

    private void ExitApp_Click(object sender, RoutedEventArgs e)
    {
        TrayIcon.Dispose();
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
        // Minimize to tray on close
        e.Cancel = true;
        Hide();
    }
}
