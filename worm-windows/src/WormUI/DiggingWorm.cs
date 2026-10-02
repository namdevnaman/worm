using System;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Shapes;
using System.Windows.Threading;

namespace Worm.UI;

/// <summary>
/// The burrowing worm, ported from DiggingWormAnimation in Theme.swift.
///
/// WPF has no TimelineView, so the per-frame redraw is driven by a
/// CompositionTarget.Rendering handler, which is the closest equivalent and
/// costs nothing while the control is not visible.
///
/// The rendering stops itself once the host is unloaded, and the tick is
/// unregistered. A panel animation that keeps a frame callback alive after the
/// page is gone is a classic source of "the app gets sluggish after visiting
/// this tab".
/// </summary>
public sealed class DiggingWorm : UserControl
{
    // Colours copied from the Swift original.
    private static readonly Color WormPink = Color.FromRgb(0xE6, 0x7A, 0x61);
    private static readonly Color Saddle = Color.FromRgb(0xFA, 0xB8, 0x9E);
    private static readonly Color Soil1 = Color.FromRgb(0x73, 0x47, 0x2E);
    private static readonly Color Soil2 = Color.FromRgb(0x9E, 0x61, 0x3D);

    private const int SegmentCount = 7;

    private readonly Canvas _canvas = new();
    private readonly Ellipse[] _body = new Ellipse[SegmentCount];
    private readonly Ellipse _eye = new();
    private readonly Ellipse _sparkle = new();
    private readonly Ellipse[] _pebbles = new Ellipse[6];

    // WPF's Ellipse has no RadiusX/RadiusY (that is Rectangle), so the radii are
    // tracked here rather than read back off the shapes.
    private readonly double[] _bodyRadius = new double[SegmentCount];
    private readonly double[] _pebbleRadius = new double[6];

    private readonly Stopwatch _clock = new();
    private EventHandler? _onRendering;
    private double _size = 64;

    public DiggingWorm()
    {
        ClipToBounds = true;
        Background = Brushes.Transparent;
        Content = _canvas;

        for (int i = 0; i < SegmentCount; i++)
        {
            var e = new Ellipse { Fill = new SolidColorBrush(WormPink) };
            _body[i] = e;
            _canvas.Children.Add(e);
        }

        _eye.Fill = new SolidColorBrush(Color.FromArgb(0xD9, 0, 0, 0));
        _canvas.Children.Add(_eye);
        _sparkle.Fill = Brushes.White;
        _canvas.Children.Add(_sparkle);

        for (int i = 0; i < _pebbles.Length; i++)
        {
            var p = new Ellipse
            {
                Fill = new SolidColorBrush(i % 2 == 0 ? Soil1 : Soil2)
            };
            _pebbles[i] = p;
            _canvas.Children.Add(p);
        }

        SizeChanged += (s, e) => Rebuild();
        Loaded += (s, e) => Start();
        Unloaded += (s, e) => Stop();
    }

    /// <summary>Nominal square size; the worm is drawn in the top 0.75 of it.</summary>
    public double WormSize
    {
        get => _size;
        set
        {
            _size = Math.Max(24, value);
            Rebuild();
        }
    }

    private void Rebuild()
    {
        var w = ActualWidth > 0 ? ActualWidth : _size;
        var h = ActualHeight > 0 ? ActualHeight : _size * 0.75;
        if (w <= 0 || h <= 0) return;

        double step = w / (SegmentCount + 2);
        double midY = h / 2;
        double headR = h * 0.25;

        for (int i = 0; i < SegmentCount; i++)
        {
            double r = i == 0 ? headR
                     : i < SegmentCount - 1 ? h * 0.20
                     : h * 0.15;

            _body[i].Width = r * 2;
            _body[i].Height = r * 2;
            _bodyRadius[i] = r;

            // The head reads lighter, matching the Swift saddle highlight.
            _body[i].Fill = new SolidColorBrush(i == 0 ? Saddle : WormPink);
        }

        double headX = step * 1.5;
        double headY = midY;

        _eye.Width = _eye.Height = Math.Max(2, h * 0.09);
        _eye.Margin = new Thickness(headX + headR * 0.25, headY - headR * 0.55, 0, 0);

        _sparkle.Width = _sparkle.Height = Math.Max(1, h * 0.03);
        _sparkle.Margin = new Thickness(headX + headR * 0.42, headY - headR * 0.62, 0, 0);

        for (int i = 0; i < _pebbles.Length; i++)
        {
            double r = i % 2 == 0 ? h * 0.05 : h * 0.035;
            _pebbles[i].Width = _pebbles[i].Height = r * 2;
            _pebbleRadius[i] = r;
        }
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

        var w = ActualWidth > 0 ? ActualWidth : _size;
        var h = ActualHeight > 0 ? ActualHeight : _size * 0.75;
        if (w <= 0 || h <= 0) return;

        double t = _clock.Elapsed.TotalSeconds;
        double step = w / (SegmentCount + 2);
        double midY = h / 2;

        for (int i = 0; i < SegmentCount; i++)
        {
            double x = step * (1.5 + i);
            // Same sine wave the Swift version uses: amplitude 0.20 of the height,
            // frequency 4.5 rad/s with a 0.75 rad phase offset per segment.
            double y = midY + Math.Sin(t * 4.5 + i * 0.75) * (h * 0.20);
            double r = _bodyRadius[i];
            Canvas.SetLeft(_body[i], x - r);
            Canvas.SetTop(_body[i], y - r);
        }

        // Flying soil, orbiting behind the tail.
        for (int i = 0; i < _pebbles.Length; i++)
        {
            double orbit = h * 0.18 * Math.Sin(t * 2.2 + i * 1.05);
            double x = w * 0.92 - orbit;
            double y = midY - h * 0.16 + Math.Cos(t * 3.1 + i) * h * 0.12;
            double r = _pebbleRadius[i];
            Canvas.SetLeft(_pebbles[i], x - r);
            Canvas.SetTop(_pebbles[i], y - r);
        }
    }

    /// <summary>
    /// The circular well the worm sits in, matching the Swift loading hero.
    /// </summary>
    public static FrameworkElement CreateHero(double diameter, string title, string subtitle)
    {
        var stack = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        var circle = new Border
        {
            Width = diameter,
            Height = diameter,
            CornerRadius = new CornerRadius(diameter / 2),
            Background = new SolidColorBrush(Color.FromRgb(0x2A, 0x26, 0x22)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(0x66, 0xC2, 0x6B, 0x47)),
            BorderThickness = new Thickness(2),
            HorizontalAlignment = HorizontalAlignment.Center
        };

        var worm = new DiggingWorm { WormSize = diameter * 0.78 };
        circle.Child = worm;

        stack.Children.Add(circle);
        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 14,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Color.FromRgb(0xF2, 0xED, 0xE8)),
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = new Thickness(0, 16, 0, 0)
        });
        stack.Children.Add(new TextBlock
        {
            Text = subtitle,
            FontSize = 11,
            Foreground = new SolidColorBrush(Color.FromRgb(0x85, 0x7D, 0x75)),
            HorizontalAlignment = HorizontalAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            MaxWidth = 320,
            Margin = new Thickness(0, 4, 0, 0)
        });

        return stack;
    }
}

/// <summary>
/// Standard empty and loading states, so every screen speaks the same visual
/// language instead of each inventing its own placeholder.
/// </summary>
public static class WormStates
{
    public static FrameworkElement Loading(string title, string subtitle)
        => DiggingWorm.CreateHero(80, title, subtitle);

    public static FrameworkElement Empty(string title, string subtitle, bool positive = false)
    {
        var stack = new StackPanel
        {
            MaxWidth = 320,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        stack.Children.Add(new TextBlock
        {
            Text = title,
            FontSize = 13,
            FontWeight = FontWeights.Medium,
            Foreground = positive
                ? new SolidColorBrush(Color.FromRgb(0xC2, 0x6B, 0x47))
                : new SolidColorBrush(Color.FromRgb(0xF2, 0xED, 0xE8)),
            HorizontalAlignment = HorizontalAlignment.Center
        });

        stack.Children.Add(new TextBlock
        {
            Text = subtitle,
            FontSize = 11,
            Foreground = new SolidColorBrush(Color.FromRgb(0x85, 0x7D, 0x75)),
            HorizontalAlignment = HorizontalAlignment.Center,
            TextWrapping = TextWrapping.Wrap,
            Margin = new Thickness(0, 6, 0, 0)
        });

        return stack;
    }
}
