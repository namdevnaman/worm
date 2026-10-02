using System;
using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using Worm.Core;

namespace Worm.UI;

public partial class SettingsPage : Page
{
    public SettingsPage()
    {
        InitializeComponent();
        Loaded += (s, e) => RefreshList();
    }

    private void RefreshList()
    {
        LstProtectedPaths.ItemsSource = WindowsSafetyPolicy.GetProtectedPaths();
    }

    private void BtnAddProtect_Click(object sender, RoutedEventArgs e)
    {
        var input = TxtNewProtect.Text?.Trim();
        if (!string.IsNullOrWhiteSpace(input))
        {
            WindowsSafetyPolicy.AddProtectedPath(input);
            TxtNewProtect.Text = string.Empty;
            RefreshList();
        }
    }

    private void BtnRemoveProtect_Click(object sender, RoutedEventArgs e)
    {
        if (LstProtectedPaths.SelectedItem is string path)
        {
            WindowsSafetyPolicy.RemoveProtectedPath(path);
            RefreshList();
        }
    }

    private void OpenRepo_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "https://github.com/namdevnaman/worm",
                UseShellExecute = true
            });
        }
        catch { }
    }

    private void OpenLogs_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (!Directory.Exists(WindowsPaths.LogDir))
                Directory.CreateDirectory(WindowsPaths.LogDir);

            Process.Start(new ProcessStartInfo
            {
                FileName = WindowsPaths.LogDir,
                UseShellExecute = true
            });
        }
        catch { }
    }
}
