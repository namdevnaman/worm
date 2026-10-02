using System.Windows;
using ModernWpf;

namespace Worm.UI;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        // Force Windows 11 Dark Mode matching Worm Loam aesthetic
        ThemeManager.Current.ApplicationTheme = ApplicationTheme.Dark;
    }
}
