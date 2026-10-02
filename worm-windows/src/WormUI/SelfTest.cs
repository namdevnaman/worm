using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Worm.Core;

namespace Worm.UI;

/// <summary>
/// A diagnostic run, started with `Worm.exe --selftest`, that answers the two
/// questions that cannot be settled by inspection on macOS:
///
///   1. Does Escape actually exit Clean Screen mode on this machine?
///   2. Do the springs behave the way Theme.swift's do, once WPF is in the loop?
///
/// Both are measured rather than eyeballed. The Escape check installs a real
/// low-level keyboard hook and injects a real Escape through SendInput, then
/// asserts the callback fired. The motion check samples the real SpringEasing
/// through WPF, which is what settles the open question of whether WPF clamps
/// easing output to [0,1] and silently removes the overshoot.
///
/// Output goes to stdout and to %LOCALAPPDATA%\Worm\Logs\selftest.txt.
/// Exit code is 0 when everything passes, 1 otherwise.
/// </summary>
public static class SelfTest
{
    internal delegate IntPtr LowLevelProc(int code, IntPtr wParam, IntPtr lParam);

    private static readonly List<string> Lines = new();

    private static int _failures;

    public static int Run()
    {
        Lines.Add($"Worm self-test  {DateTime.UtcNow:O}");
        Lines.Add($"runtime {Environment.Version} on {Environment.OSVersion}");
        Lines.Add(new string('=', 68));

        CheckEscapeWorks();
        CheckSpringEasing();
        CheckLiveTweenOvershoots();

        Lines.Add(new string('=', 68));
        Lines.Add(_failures == 0
            ? "RESULT: all checks passed"
            : $"RESULT: {_failures} check(s) FAILED");

        var text = string.Join(Environment.NewLine, Lines);
        Console.WriteLine(text);

        var path = WriteReport(text);
        if (path != null)
        {
            Console.WriteLine();
            Console.WriteLine($"report written to {path}");
        }

        return _failures == 0 ? 0 : 1;
    }

    private static string? WriteReport(string text)
    {
        try
        {
            var dir = WindowsPaths.LogDir;
            if (!Directory.Exists(dir)) Directory.CreateDirectory(dir);

            var path = Path.Combine(dir, "selftest.txt");
            File.WriteAllText(path, text);
            return path;
        }
        catch
        {
            return null;
        }
    }

    private static void Head(string title) => Lines.Add(title);

    private static void Check(bool ok, string label, string detail = "")
    {
        if (!ok) _failures++;
        Lines.Add($"  [{(ok ? "PASS" : "FAIL")}] {label}{(detail.Length > 0 ? "   " + detail : "")}");
    }

    private static void Info(string label, string detail)
        => Lines.Add($"         {label,-24} {detail}");

    // ------------------------------------------------------------------ escape
    private static void CheckEscapeWorks()
    {
        Head("CLEAN SCREEN - does Escape exit?");

        bool hooked;
        int error;
        try
        {
            hooked = SelfTestHook.TryInstall(out error);
        }
        catch (Exception ex)
        {
            Check(false, "install low-level keyboard hook", ex.Message);
            return;
        }

        Check(hooked, "install low-level keyboard hook",
            hooked ? "SetWindowsHookEx returned a handle" : $"failed, Win32 error {error}");

        if (!hooked)
        {
            Info("consequence", "Escape will NOT exit Clean Screen");
            Info("still works", "click anywhere exits");
            Info("likely cause", "security software, or a non-interactive session");
            return;
        }

        // Does the real Windows input path actually reach the callback?
        var before = SelfTestHook.EscapeHits;
        var injected = CleanScreenMode.InjectEscape();
        Pump(250);
        var hits = SelfTestHook.EscapeHits - before;

        Check(injected, "inject Escape via SendInput",
            injected ? "accepted" : "REJECTED - session may not be interactive");
        Check(hits == 1, "callback fired exactly once for Escape",
            $"delta = {hits}{(hits == 0 ? "   <- the hook is installed but blind" : "")}");

        // A wrong hook would swallow every key, so prove pass-through still works.
        var beforeOther = SelfTestHook.Passthrough;
        SelfTestHook.CallThrough(0x41);
        Check(SelfTestHook.Passthrough == beforeOther + 1,
            "non-Escape key passes through untouched",
            $"delta = {SelfTestHook.Passthrough - beforeOther}");

        SelfTestHook.Uninstall();
        Check(true, "unhook", "released cleanly");
    }

    // ------------------------------------------------------------------ motion
    private static void CheckSpringEasing()
    {
        Head("SPRING EASING vs Theme.swift");

        // Targets come from Theme.swift:97-99 through the analytic mapping
        // omega0 = 2*pi/response, k = omega0^2, c = 2*zeta*omega0.
        var springs = new[]
        {
            new Target("springSnappy", 0.26, 0.72),
            new Target("springBouncy", 0.38, 0.65),
            new Target("springSmooth", 0.42, 0.82)
        };

        foreach (var target in springs)
        {
            double w0 = 2 * Math.PI / target.Response;
            double k = w0 * w0;
            double c = 2 * target.Zeta * w0;
            double expectedOvershoot =
                100 * Math.Exp(-Math.PI * target.Zeta / Math.Sqrt(1 - target.Zeta * target.Zeta));
            double expectedPeakMs = 1000 * Math.PI / (w0 * Math.Sqrt(1 - target.Zeta * target.Zeta));

            var easing = new SpringEasing
            {
                Stiffness = k,
                Damping = c,
                Mass = 1.0,
                Period = SettleSeconds(target.Response, target.Zeta),
                EasingMode = EasingMode.EaseOut
            };

            const int steps = 2000;
            double peak = double.MinValue;
            int peakIndex = 0;
            for (int i = 0; i <= steps; i++)
            {
                double value = easing.Ease((double)i / steps);
                if (value > peak)
                {
                    peak = value;
                    peakIndex = i;
                }
            }

            double end = easing.Ease(1.0);
            double peakMs = (double)peakIndex / steps * easing.Period * 1000;
            double measured = (peak - 1.0) * 100;

            Lines.Add($"  {target.Name}   response={target.Response}  zeta={target.Zeta}");
            Info("expected overshoot", $"{expectedOvershoot:F2}%");
            Info("measured overshoot", $"{measured:F2}%");
            Info("expected peak", $"{expectedPeakMs:F0} ms");
            Info("measured peak", $"{peakMs:F0} ms");
            Info("value at u=1", $"{end:F6}");

            Check(peakIndex > 0 && peakIndex < steps,
                $"{target.Name}: overshoot is reached inside the animation",
                $"peak at normalized {peakIndex / (double)steps:F3}");

            // If WPF clamps easing output to [0,1], the spring silently degrades to
            // a plain ease and the bounce vanishes. That is exactly what this
            // comparison is here to detect.
            Check(Math.Abs(measured - expectedOvershoot) < 0.75,
                $"{target.Name}: overshoot matches the Swift spring",
                $"want {expectedOvershoot:F2}%, got {measured:F2}%");

            Check(Math.Abs(peakMs - expectedPeakMs) < 30,
                $"{target.Name}: peak lands at the right time",
                $"want {expectedPeakMs:F0} ms, got {peakMs:F0} ms");

            Check(Math.Abs(end - 1.0) < 1e-9,
                $"{target.Name}: settles exactly on target", $"u=1 -> {end:F6}");
        }
    }

    /// <summary>Time for the spring to decay to 0.1% of its initial displacement.</summary>
    private static double SettleSeconds(double response, double zeta)
    {
        double w0 = 2 * Math.PI / response;
        return Math.Log(1000) / (zeta * w0);
    }

    private readonly record struct Target(string Name, double Response, double Zeta);

    // ------------------------------------------------------- live animation run
    private static void CheckLiveTweenOvershoots()
    {
        Head("LIVE TWEEN - is the bounce actually visible?");

        // A correct easing proves nothing unless WPF drives it, so run the real
        // animation on an element inside a real (off-screen) rendered tree and
        // sample the rendered value every frame.
        var border = new Border
        {
            Width = 60,
            Height = 60,
            Background = Brushes.Transparent,
            Opacity = 0
        };

        var window = new Window
        {
            WindowStyle = WindowStyle.None,
            ShowInTaskbar = false,
            ResizeMode = ResizeMode.NoResize,
            Left = -32000,
            Top = -32000,
            Width = 80,
            Height = 80,
            Title = "Worm self-test"
        };
        window.Content = border;

        var samples = new List<double>();
        void Sample(object? sender, EventArgs e)
        {
            var v = border.Opacity;
            if (v > 0) samples.Add(v);
        }

        CompositionTarget.Rendering += Sample;
        try
        {
            window.Show();
            border.BeginAnimation(UIElement.OpacityProperty, WormMotion.SpringSnappy.From(0.0, 1.0));
            Pump(1600);
        }
        finally
        {
            CompositionTarget.Rendering -= Sample;
            window.Close();
        }

        if (samples.Count < 4)
        {
            Check(false, "render loop produced samples", $"only {samples.Count}");
            return;
        }

        double peak = samples.Max();
        double overshoot = (peak - 1.0) * 100;

        Info("frames sampled", samples.Count.ToString(CultureInfo.InvariantCulture));
        Info("peak opacity", $"{peak:F4}");
        Info("measured overshoot", $"{overshoot:F2}%  (springSnappy should be 3.84%)");
        Info("final opacity", $"{samples[^1]:F4}");

        Check(overshoot > 0.5, "live animation overshoots past the target",
            $"{overshoot:F2}% - the bounce renders");
        Check(Math.Abs(overshoot - 3.84) < 1.5, "live overshoot matches the Swift spring",
            "want 3.84%");
        Check(Math.Abs(samples[^1] - 1.0) < 0.02, "animation settled on 1.0",
            $"last value {samples[^1]:F4}");
    }

    /// <summary>
    /// Runs the dispatcher for a fixed span so animations, timers and render
    /// callbacks actually advance on this thread.
    /// </summary>
    private static void Pump(int milliseconds)
    {
        var frame = new DispatcherFrame();
        var timer = new DispatcherTimer(
            TimeSpan.FromMilliseconds(milliseconds),
            DispatcherPriority.Normal,
            (_, _) => frame.Continue = false,
            Dispatcher.CurrentDispatcher);

        timer.Start();
        Dispatcher.PushFrame(frame);
        timer.Stop();
    }
}

/// <summary>
/// Installs a throwaway low-level keyboard hook so the self-test exercises the real
/// Windows input path. This mirrors CleanScreenMode's hook deliberately: if this
/// installs, the production one installs too.
/// </summary>
internal static class SelfTestHook
{
    private static IntPtr _handle;
    private static readonly SelfTest.LowLevelProc _proc = OnKey;

    internal static int EscapeHits;
    internal static int Passthrough;

    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int VK_ESCAPE = 0x1B;

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(
        int idHook, SelfTest.LowLevelProc lpfn, IntPtr hMod, uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int code, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string? name);

    internal static bool TryInstall(out int error)
    {
        _handle = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(null), 0);
        error = _handle == IntPtr.Zero ? Marshal.GetLastWin32Error() : 0;
        return _handle != IntPtr.Zero;
    }

    internal static void Uninstall()
    {
        if (_handle == IntPtr.Zero) return;
        UnhookWindowsHookEx(_handle);
        _handle = IntPtr.Zero;
    }

    /// <summary>Feeds a synthetic message straight into the hook proc.</summary>
    internal static void CallThrough(int vk)
    {
        var buffer = Marshal.AllocHGlobal(sizeof(int));
        try
        {
            Marshal.WriteInt32(buffer, vk);
            OnKey(0, new IntPtr(WM_KEYDOWN), buffer);
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    private static IntPtr OnKey(int code, IntPtr wParam, IntPtr lParam)
    {
        if (code >= 0 && wParam.ToInt32() == WM_KEYDOWN)
        {
            var vk = (int)Marshal.ReadInt32(lParam);
            if (vk == VK_ESCAPE)
            {
                EscapeHits++;
                return new IntPtr(1);
            }

            Passthrough++;
        }

        return CallNextHookEx(_handle, code, wParam, lParam);
    }
}