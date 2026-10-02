using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Shapes;

namespace Worm.UI;

/// <summary>
/// The 6-segment munching worm from EatingWormAnimation in Theme.swift.
///
/// Same maths as the Swift original: chew = sin(t*12), wiggle = sin(t*5), body
/// segments stepping left from 0.48 of the width, five crumbs flying in from the
/// right, and a mouth that opens with the chew wave.
///
/// Derives from Canvas because the shapes are positioned with Canvas.SetLeft /
/// Canvas.SetTop; WPF's Ellipse has no RadiusX/RadiusY, so circles come from
/// equal Width and Height.
/// </summary>
public sealed class EatingWorm : Canvas
{
    private static readonly Color WormPink = Color.FromRgb(0xE6, 0x7A, 0x61);
    private static readonly Color Saddle = Color.FromRgb(0xFA, 0xB8, 0x9E);
    private static readonly Color Mouth = Color.FromRgb(0x52, 0x1A, 0x14);
    private static readonly Color Crumb1 = Color.FromRgb(0x85, 0x52, 0x38);
    private static readonly Color Crumb2 = Color.FromRgb(0xC7, 0x7A, 0x47);

    private const int Segments = 6;
    private const int Crumbs = 5;

    private readonly Ellipse[] _body = new Ellipse[Segments];
    private readonly Ellipse[] _crumbs = new Ellipse[Crumbs];
    private readonly Ellipse _mouth = new();
    private readonly Ellipse _eye = new();

    private readonly System.Diagnostics.Stopwatch _clock = new();
    private EventHandler? _onRendering;

    public double WormSize { get; set; } = 80;

    public EatingWorm()
    {
        ClipToBounds = true;

        for (int i = 0; i < Segments; i++)
        {
            var e = new Ellipse { Fill = new SolidColorBrush(i == 0 ? Saddle : WormPink) };
            _body[i] = e;
            Children.Add(e);
        }

        _mouth.Fill = new SolidColorBrush(Mouth);
        Children.Add(_mouth);

        _eye.Fill = new SolidColorBrush(Color.FromArgb(0xD9, 0, 0, 0));
        Children.Add(_eye);

        for (int i = 0; i < Crumbs; i++)
        {
            var c = new Ellipse { Fill = new SolidColorBrush(i % 2 == 0 ? Crumb1 : Crumb2) };
            _crumbs[i] = c;
            Children.Add(c);
        }

        Loaded += (_, _) => Start();
        Unloaded += (_, _) => Stop();
    }

    private void Start()
    {
        if (_onRendering != null) return;
        _clock.Start();
        _onRendering = (s, e) => Frame();
        CompositionTarget.Rendering += _onRendering;
    }

    private void Stop()
    {
        if (_onRendering == null) return;
        CompositionTarget.Rendering -= _onRendering;
        _onRendering = null;
        _clock.Stop();
    }

    private void Frame()
    {
        if (!IsVisible) return;

        double w = ActualWidth > 0 ? ActualWidth : WormSize;
        double h = ActualHeight > 0 ? ActualHeight : WormSize * 0.55;
        if (w <= 0 || h <= 0) return;

        double t = _clock.Elapsed.TotalSeconds;
        double chew = Math.Sin(t * 12.0);
        double wiggle = Math.Sin(t * 5.0);
        double midY = h / 2;

        for (int i = 0; i < Crumbs; i++)
        {
            double offset = (t * 45.0 + i * 14.0) % 36.0;
            double cx = w * 0.86 - offset;
            double cy = midY + Math.Sin(i * 1.3 + t * 3.5) * (h * 0.20);
            double r = i % 2 == 0 ? 3.5 : 2.5;

            _crumbs[i].Width = r * 2;
            _crumbs[i].Height = r * 2;
            Canvas.SetLeft(_crumbs[i], cx - r);
            Canvas.SetTop(_crumbs[i], cy - r);
        }

        for (int i = 0; i < Segments; i++)
        {
            double x = w * 0.48 - i * 10;
            double y = midY + Math.Sin(i * 0.85 + wiggle) * (h * 0.16);
            double r = i == 0 ? 9.5 : 8.5 - i * 0.6;

            _body[i].Width = r * 2;
            _body[i].Height = r * 2;
            Canvas.SetLeft(_body[i], x - r);
            Canvas.SetTop(_body[i], y - r);
        }

        double mouthX = w * 0.48;
        double mouthH = Math.Max(3, 7 + chew * 5);

        _mouth.Width = 7.5;
        _mouth.Height = mouthH;
        Canvas.SetLeft(_mouth, mouthX);
        Canvas.SetTop(_mouth, midY - mouthH / 2);

        _eye.Width = 3.5;
        _eye.Height = 3.5;
        Canvas.SetLeft(_eye, mouthX - 5.5 - 1.75);
        Canvas.SetTop(_eye, midY - 6 - 1.75);
    }
}

/// <summary>
/// Clean Screen mode, ported from CleanScreenController / CleanScreenOverlayView.
///
/// One borderless black window per monitor at tool-window level, the cursor
/// hidden, Esc or a click anywhere to exit. This is the macOS feature that lets
/// you wipe a display down with a cloth without smearing it.
///
/// Monitor rectangles come from EnumDisplayMonitors rather than WinForms, which
/// this project does not reference.
/// </summary>
public static class CleanScreenMode
{
    private static readonly List<Window> Blackouts = new();
    private static Cursor? _previousCursor;
    private static IntPtr _hookHandle;
    private static int _escapeCount;

    /// <summary>
    /// Held in a static field so the GC never collects the delegate while the
    /// hook is installed; a collected callback means a dangling function pointer
    /// inside the OS input stack.
    /// </summary>
    private static readonly LowLevelKeyboardProc _keyProc = OnKeyDown;

    public static bool IsActive => Blackouts.Count > 0;

    /// <summary>
    /// Whether the Escape hook is currently installed. Exposed so the self-test can
    /// assert the real path rather than a mock of it.
    /// </summary>
    public static bool IsEscapeHooked => _hookHandle != IntPtr.Zero;

    /// <summary>Live count of Escape keys intercepted since launch.</summary>
    public static int EscapeCount => _escapeCount;

    public static void Show()
    {
        if (IsActive) return;

        _previousCursor = Mouse.OverrideCursor;

        try
        {
            // Install the hook before the overlays are built so the on-screen hint
            // can tell the truth about whether Esc will work on this machine.
            bool escapeWorks = HookEscape();

            foreach (var bounds in MonitorBounds())
            {
                var window = BuildOverlay(bounds, escapeWorks);
                Blackouts.Add(window);
                window.Show();
            }

            Mouse.OverrideCursor = Cursors.None;
        }
        catch (Exception ex)
        {
            Worm.Core.WindowsCrashLog.Write("CleanScreenMode.Show", ex);
            Hide();
        }
    }

    public static void Hide()
    {
        foreach (var window in Blackouts)
        {
            try { window.Close(); } catch { /* already gone */ }
        }
        Blackouts.Clear();

        try
        {
            if (_previousCursor != null) Mouse.OverrideCursor = _previousCursor;
        }
        catch { }
        _previousCursor = null;

        if (_hookHandle != IntPtr.Zero)
        {
            UnhookWindowsHookEx(_hookHandle);
            _hookHandle = IntPtr.Zero;
        }
    }

    // --------------------------------------------------------------- escape key
    private delegate IntPtr LowLevelKeyboardProc(int code, IntPtr wParam, IntPtr lParam);

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private const int VK_ESCAPE = 0x1B;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);

    [StructLayout(LayoutKind.Sequential)]
    internal struct Input
    {
        public uint Type;
        public InputUnion Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    internal struct InputUnion
    {
        [FieldOffset(0)] public KeyboardInput Keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct KeyboardInput
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    internal const uint InputKeyboard = 1;
    internal const uint KeyEventKeyUp = 0x0002;

    /// <summary>
    /// Injects a synthetic Escape so the self-test can prove the hook actually fires
    /// rather than merely installing. Returns false if SendInput was rejected, which
    /// happens when the session is not interactive.
    /// </summary>
    internal static bool InjectEscape()
    {
        var inputs = new[]
        {
            new Input
            {
                Type = InputKeyboard,
                Data = new InputUnion
                {
                    Keyboard = new KeyboardInput { VirtualKey = VK_ESCAPE }
                }
            },
            new Input
            {
                Type = InputKeyboard,
                Data = new InputUnion
                {
                    Keyboard = new KeyboardInput { VirtualKey = VK_ESCAPE, Flags = KeyEventKeyUp }
                }
            }
        };

        var sent = SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>());
        return sent == inputs.Length;
    }

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int code, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string? moduleName);

    /// <summary>
    /// Escape is caught with a low-level keyboard hook rather than a WPF key event.
    /// The overlay sets WS_EX_NOACTIVATE so it cannot steal focus from whatever the
    /// user was doing, which also means it never receives KeyDown. A WH_KEYBOARD_LL
    /// hook runs before focus dispatch, so it sees Escape anyway.
    ///
    /// Only VK_ESCAPE is consumed; every other key is passed straight to the rest of
    /// the system via CallNextHookEx, and the hook is uninstalled on Hide.
    /// </summary>
    private static bool HookEscape()
    {
        if (_hookHandle != IntPtr.Zero) return true;

        var module = GetModuleHandle(null);
        _hookHandle = SetWindowsHookEx(WH_KEYBOARD_LL, _keyProc, module, 0);

        if (_hookHandle != IntPtr.Zero) return true;

        // The overlay still works via click-to-exit, so this degrades rather than
        // fails. It is logged and surfaced in the overlay text, because a silently
        // dead Esc key would look identical to "Esc is broken" during testing.
        Worm.Core.WindowsCrashLog.Write(
            "CleanScreenMode.SetWindowsHookEx",
            new Win32Exception(Marshal.GetLastWin32Error()));
        return false;
    }

    internal static IntPtr OnKeyDownForTest(int code, IntPtr wParam, IntPtr lParam)
        => OnKeyDown(code, wParam, lParam);

    private static IntPtr OnKeyDown(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0 && (wParam.ToInt32() == WM_KEYDOWN || wParam.ToInt32() == WM_SYSKEYDOWN))
        {
            var key = (int)Marshal.ReadInt32(lParam);
            if (key == VK_ESCAPE)
            {
                Interlocked.Increment(ref _escapeCount);

                // The hook fires on the thread that installed it, which owns the
                // overlay windows, but marshalling keeps this safe if that changes.
                var dispatcher = Application.Current?.Dispatcher;
                if (dispatcher != null && !dispatcher.CheckAccess())
                {
                    dispatcher.BeginInvoke(new Action(Hide));
                }
                else
                {
                    Hide();
                }

                return new IntPtr(1);
            }
        }

        return CallNextHookEx(_hookHandle, code, wParam, lParam);
    }

    private static Window BuildOverlay(Rect bounds, bool escapeWorks)
    {
        var window = new Window
        {
            WindowStyle = WindowStyle.None,
            AllowsTransparency = false,
            ResizeMode = ResizeMode.NoResize,
            ShowInTaskbar = false,
            Topmost = true,
            WindowState = WindowState.Normal,
            Background = Brushes.Black,
            ShowActivated = false,
            Focusable = false,
            Left = bounds.Left,
            Top = bounds.Top,
            Width = bounds.Width,
            Height = bounds.Height
        };

        // Tool-window + no-activate, the Windows equivalent of putting the window
        // at .screenSaver level on macOS.
        var helper = new WindowInteropHelper(window);
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x00000080;
        const int WS_EX_NOACTIVATE = 0x08000000;
        var style = GetWindowLong(helper.Handle, GWL_EXSTYLE);
        SetWindowLong(helper.Handle, GWL_EXSTYLE, style | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE);

        var stack = new StackPanel
        {
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center
        };

        stack.Children.Add(new EatingWorm { WormSize = 90 });

        stack.Children.Add(new TextBlock
        {
            Text = "Clean Screen Mode Active",
            FontSize = 20,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brushes.White,
            Margin = new Thickness(0, 20, 0, 0),
            HorizontalAlignment = HorizontalAlignment.Center
        });

        stack.Children.Add(new TextBlock
        {
            Text = escapeWorks
                ? "Wipe down your display safely.\nPress Esc or click anywhere to exit."
                : "Wipe down your display safely.\nClick anywhere to exit.\n(Esc unavailable: keyboard hook blocked)",
            FontSize = 13,
            Foreground = new SolidColorBrush(Color.FromArgb(0xA6, 0xFF, 0xFF, 0xFF)),
            TextAlignment = TextAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 8, 0, 0)
        });

        var exit = new Button
        {
            Content = "Exit Clean Screen",
            Margin = new Thickness(0, 22, 0, 0),
            Padding = new Thickness(16, 8, 16, 8),
            Background = new SolidColorBrush(Color.FromRgb(0xC2, 0x6B, 0x47)),
            Foreground = Brushes.White,
            FontSize = 12,
            FontWeight = FontWeights.Medium,
            BorderThickness = new Thickness(0),
            Cursor = Cursors.Hand,
            FocusVisualStyle = null,
            Template = FlatTemplate()
        };
        exit.Click += (_, _) => Hide();
        stack.Children.Add(exit);

        var root = new Grid { Background = Brushes.Black };
        root.Children.Add(stack);
        window.Content = root;

        // Clicking anywhere exits, matching the Swift overlay's tap gesture.
        window.PreviewMouseDown += (_, _) => Hide();

        return window;
    }

    private static ControlTemplate FlatTemplate()
    {
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.BackgroundProperty,
            new SolidColorBrush(Color.FromRgb(0xC2, 0x6B, 0x47)));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(8));

        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
        border.AppendChild(presenter);

        return new ControlTemplate(typeof(Button)) { VisualTree = border };
    }

    // ---------------------------------------------------------- monitor bounds
    private delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdc, IntPtr rect, IntPtr data);

    [StructLayout(LayoutKind.Sequential)]
    private struct NativeRect
    {
        public int Left, Top, Right, Bottom;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc proc, IntPtr data);

    [DllImport("user32.dll")]
    private static extern bool GetMonitorInfo(IntPtr monitor, ref MonitorInfo info);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
    private struct MonitorInfo
    {
        public int Size;
        public NativeRect Monitor;
        public NativeRect Work;
        public uint Flags;
    }

    private static List<Rect> MonitorBounds()
    {
        var results = new List<Rect>();

        // Per-monitor device pixels are converted through the DPI of the primary
        // monitor, matching how WPF's Left/Top/Width/Height are interpreted.
        double scale = 1.0;
        try
        {
            var dpi = VisualTreeHelper.GetDpi(new Border());
            scale = dpi.PixelsPerInchX / 96.0;
            if (scale <= 0) scale = 1.0;
        }
        catch { }

        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (h, _, _, _) =>
        {
            var info = new MonitorInfo { Size = Marshal.SizeOf<MonitorInfo>() };
            if (GetMonitorInfo(h, ref info))
            {
                results.Add(new Rect(
                    info.Monitor.Left / scale,
                    info.Monitor.Top / scale,
                    (info.Monitor.Right - info.Monitor.Left) / scale,
                    (info.Monitor.Bottom - info.Monitor.Top) / scale));
            }
            return true;
        }, IntPtr.Zero);

        if (results.Count == 0)
        {
            results.Add(new Rect(0, 0, SystemParameters.VirtualScreenWidth,
                                      SystemParameters.VirtualScreenHeight));
        }

        return results;
    }

    [DllImport("user32.dll", EntryPoint = "GetWindowLongPtr")]
    private static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", EntryPoint = "GetWindowLong")]
    private static extern int GetWindowLong32(IntPtr hWnd, int nIndex);

    private static int GetWindowLong(IntPtr hWnd, int nIndex)
        => IntPtr.Size == 8 ? GetWindowLongPtr(hWnd, nIndex).ToInt32() : GetWindowLong32(hWnd, nIndex);

    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")]
    private static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int nIndex, IntPtr newLong);

    [DllImport("user32.dll", EntryPoint = "SetWindowLong")]
    private static extern int SetWindowLong32(IntPtr hWnd, int nIndex, int newLong);

    private static void SetWindowLong(IntPtr hWnd, int nIndex, int newLong)
    {
        if (IntPtr.Size == 8) SetWindowLongPtr(hWnd, nIndex, new IntPtr(newLong));
        else SetWindowLong32(hWnd, nIndex, newLong);
    }
}
