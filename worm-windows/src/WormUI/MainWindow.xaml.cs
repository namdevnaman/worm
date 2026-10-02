using System;
using System.Windows;
using ModernWpf.Controls;

namespace Worm.UI;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        Loaded += MainWindow_Loaded;
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
            ContentFrame.Navigate(new SettingsPage());
            return;
        }

        if (args.SelectedItem is NavigationViewItem item)
        {
            switch (item.Tag?.ToString())
            {
                case "Clean":
                    ContentFrame.Navigate(new CleanPage());
                    break;
                case "Leftovers":
                    ContentFrame.Navigate(new LeftoversPage());
                    break;
                case "Status":
                    ContentFrame.Navigate(new StatusPage());
                    break;
            }
        }
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
