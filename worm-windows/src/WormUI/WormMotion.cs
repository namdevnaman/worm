using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace Worm.UI;

/// <summary>
/// Motion primitives ported from Theme.swift.
///
/// The three named SwiftUI springs are reproduced as real damped-spring curves
/// rather than approximated with BackEase. SwiftUI's
///
///     Animation.spring(response: R, dampingFraction: z)
///
/// describes a second-order system whose oscillation period is R seconds, so
/// omega0 = 2*pi/R and zeta = z. At unit mass that maps onto WPF's physical spring
/// parameters directly:
///
///     Stiffness = omega0^2,  Damping = 2*zeta*omega0,  Mass = 1
///
/// which is what <see cref="Spring"/> encodes. Note the macOS original never uses
/// SwiftUI's `bounce:` parameter, so there is nothing extra to reproduce: the
/// overshoot below is the emergent result of zeta, not a tuned constant.
///
///   name             response  zeta    stiffness  damping  overshoot  settle
///   springSnappy      0.26    0.72     584.00    34.80     3.84%      397 ms
///   springBouncy      0.38    0.65     273.40    21.50     6.81%      643 ms
///   springSmooth      0.42    0.82     223.80    24.53     1.11%      563 ms
/// </summary>
public static class WormMotion
{
    private static readonly Duration BouncyDuration = new(TimeSpan.FromMilliseconds(700));
    private static readonly Duration SmoothDuration = new(TimeSpan.FromMilliseconds(620));
    private static readonly Duration SnappyDuration = new(TimeSpan.FromMilliseconds(440));
    private static readonly Duration Quick = new(TimeSpan.FromMilliseconds(150));

    /// <summary>Theme.springBouncy - drives the checkbox tick (value: isOn).</summary>
    public static Spring SpringBouncy => new(273.40, 21.50, 1.0, BouncyDuration);

    /// <summary>Theme.springSmooth - progress bars and count changes.</summary>
    public static Spring SpringSmooth => new(223.80, 24.53, 1.0, SmoothDuration);

    /// <summary>Theme.springSnappy - button press and the most common transition.</summary>
    public static Spring SpringSnappy => new(584.00, 34.80, 1.0, SnappyDuration);

    private static CubicEase EaseOut() => new() { EasingMode = EasingMode.EaseOut };

    public static DoubleAnimation Fade(double from, double to, bool quick = false)
        => new(from, to, quick ? Quick : SmoothDuration)
        {
            FillBehavior = FillBehavior.HoldEnd,
            EasingFunction = EaseOut()
        };

    /// <summary>Page change: the incoming page rises 10px and fades in.</summary>
    public static void AnimatePageIn(FrameworkElement element)
    {
        if (element == null) return;

        var translate = new TranslateTransform(0, 10);
        element.RenderTransform = translate;
        element.Opacity = 0;

        element.BeginAnimation(UIElement.OpacityProperty, Fade(0, 1));

        // The rise lands on the snappy spring, matching the pressed-state feel.
        translate.BeginAnimation(TranslateTransform.YProperty,
            new DoubleAnimation(10, 0, SnappyDuration)
            {
                FillBehavior = FillBehavior.HoldEnd,
                EasingFunction = EaseOut()
            });
    }

    /// <summary>
    /// Hover highlight for list rows and cards: a small scale-up and a slight dim,
    /// matching the macOS FluidButtonStyle press feel.
    /// </summary>
    public static void AnimateHover(FrameworkElement element, bool hovered)
    {
        if (element == null) return;

        var from = element.Opacity;
        var to = hovered ? 0.88 : 1.0;
        element.BeginAnimation(UIElement.OpacityProperty, Fade(from, to));

        if (element.RenderTransform is not ScaleTransform scale)
        {
            scale = new ScaleTransform(1, 1);
            element.RenderTransform = scale;
        }

        // Scale rides springSnappy, the same spring macOS uses for isPressed.
        scale.BeginAnimation(ScaleTransform.ScaleXProperty,
            SpringSnappy.From(scale.ScaleX, hovered ? 1.015 : 1.0));
        scale.BeginAnimation(ScaleTransform.ScaleYProperty,
            SpringSnappy.From(scale.ScaleY, hovered ? 1.015 : 1.0));
    }

    /// <summary>
    /// Attaches the hover animation to a row. Kept separate so callers do not have
    /// to remember to remove the handlers.
    /// </summary>
    public static void AttachHover(FrameworkElement element)
    {
        element.MouseEnter += (_, _) => AnimateHover(element, true);
        element.MouseLeave += (_, _) => AnimateHover(element, false);
    }

    internal static SolidColorBrush Brush(byte a, byte r, byte g, byte b)
        => new(Color.FromArgb(a, r, g, b));
}

/// <summary>
/// A SwiftUI spring expressed in WPF's physical spring units, evaluated analytically.
///
/// WPF has no spring easing of its own - EasingFunctionBase only ships Linear, Quad,
/// Cubic, Quart, Quint, Sine, Expo, Circ, Back and Bounce - so this reproduces the
/// closed-form unit-step response of the second-order system rather than dressing a
/// cubic up as a spring. Because it is a real EasingFunction, the overshoot is
/// preserved instead of being clamped away.
/// </summary>
public sealed class SpringEasing : EasingFunctionBase
{
    public static readonly DependencyProperty StiffnessProperty = DependencyProperty.Register(
        nameof(Stiffness), typeof(double), typeof(SpringEasing),
        new FrameworkPropertyMetadata(273.40));

    public static readonly DependencyProperty DampingProperty = DependencyProperty.Register(
        nameof(Damping), typeof(double), typeof(SpringEasing),
        new FrameworkPropertyMetadata(21.50));

    public static readonly DependencyProperty MassProperty = DependencyProperty.Register(
        nameof(Mass), typeof(double), typeof(SpringEasing),
        new FrameworkPropertyMetadata(1.0));

    /// <summary>Physical duration of the spring, in seconds.</summary>
    public static readonly DependencyProperty PeriodProperty = DependencyProperty.Register(
        nameof(Period), typeof(double), typeof(SpringEasing),
        new FrameworkPropertyMetadata(0.70));

    public double Stiffness
    {
        get => (double)GetValue(StiffnessProperty);
        set => SetValue(StiffnessProperty, value);
    }

    public double Damping
    {
        get => (double)GetValue(DampingProperty);
        set => SetValue(DampingProperty, value);
    }

    public double Mass
    {
        get => (double)GetValue(MassProperty);
        set => SetValue(MassProperty, value);
    }

    public double Period
    {
        get => (double)GetValue(PeriodProperty);
        set => SetValue(PeriodProperty, value);
    }

    protected override Freezable CreateInstanceCore() => new SpringEasing
    {
        Stiffness = Stiffness,
        Damping = Damping,
        Mass = Mass,
        Period = Period
    };

    /// <summary>
    /// Unit-step response of an underdamped spring starting from rest:
    ///
    ///   x(t) = 1 - e^(-z*w0*t) [ cos(wd*t) + (z / sqrt(1-z^2)) sin(wd*t) ]
    ///
    /// where z = c / (2*sqrt(k*m)) is the damping ratio and wd = w0*sqrt(1-z^2).
    /// The critically damped case (z >= 1) uses 1 - e^(-w0*t)(1 + w0*t).
    ///
    /// WPF feeds normalized time in [0,1] across the animation Duration, so the
    /// normalized value is scaled by Period to recover physical time.
    ///
    /// EasingFunctionBase only declares EaseInCore and derives EaseOut as
    /// 1 - EaseInCore(1 - t). A spring released from rest is EaseOut-shaped, so the
    /// curve is defined here in its natural form and mirrored for EaseIn, and the
    /// instances are created with EasingMode.EaseOut.
    /// </summary>
    private double SpringCore(double normalizedTime)
    {
        if (normalizedTime <= 0.0) return 0.0;

        // Snap exactly to the target at the end. The analytic curve is asymptotic,
        // so leaving it alone would hold the property ~0.1% short of the target
        // forever under FillBehavior.HoldEnd.
        if (normalizedTime >= 1.0) return 1.0;

        double t = normalizedTime * Period;
        double mass = Mass <= 0 ? 1.0 : Mass;
        double stiffness = Stiffness <= 0 ? 1.0 : Stiffness;

        double w0 = Math.Sqrt(stiffness / mass);
        double zeta = Damping / (2.0 * Math.Sqrt(stiffness * mass));

        if (zeta >= 1.0)
            return 1.0 - Math.Exp(-w0 * t) * (1.0 + w0 * t);

        double root = Math.Sqrt(1.0 - zeta * zeta);
        double wd = w0 * root;

        return 1.0 - Math.Exp(-zeta * w0 * t) *
                     (Math.Cos(wd * t) + (zeta / root) * Math.Sin(wd * t));
    }

    protected override double EaseInCore(double normalizedTime)
        => 1.0 - SpringCore(1.0 - normalizedTime);
}

/// <summary>
/// A SwiftUI spring expressed in WPF's physical spring units.
/// </summary>
public readonly struct Spring
{
    public Spring(double stiffness, double damping, double mass, Duration settle)
    {
        Stiffness = stiffness;
        Damping = damping;
        Mass = mass;
        Settle = settle;
    }

    public double Stiffness { get; }
    public double Damping { get; }
    public double Mass { get; }

    /// <summary>
    /// How long to let the spring run. This is the time to decay to 0.1% of the
    /// initial displacement, rounded up.
    /// </summary>
    public Duration Settle { get; }

    /// <summary>
    /// Animates a double from one value to another along this spring.
    ///
    /// The spring is used as an easing function, so it shapes progress rather than
    /// driving an absolute value. Overshoot is therefore measured against the
    /// displacement, exactly as a physical spring behaves.
    /// </summary>
    public DoubleAnimation From(double from, double to)
        => new(from, to, Settle)
        {
            FillBehavior = FillBehavior.HoldEnd,
            EasingFunction = new SpringEasing
            {
                Stiffness = Stiffness,
                Damping = Damping,
                Mass = Mass,
                Period = Settle.TimeSpan.TotalSeconds,
                EasingMode = EasingMode.EaseOut
            }
        };
}

public sealed class CheckChangedEventArgs : EventArgs
{
    public CheckChangedEventArgs(bool isChecked) => IsChecked = isChecked;
    public bool IsChecked { get; }
}

/// <summary>
/// The app-drawn checkbox from Components.swift, with the tick animated.
///
/// Deliberately a Control rather than a ToggleButton: the macOS original reads
/// purely from isOn and draws its own box, which is why it cannot end up showing a
/// stale tick when the underlying state changes without a click. A two-way
/// ToggleButton binding reproduces exactly that bug.
/// </summary>
public sealed class WormCheckBox : ContentControl
{
    private readonly Border _box;
    private readonly Path _tick;
    private readonly Border _partial;

    private static readonly SolidColorBrush Accent = new(Color.FromRgb(0xC2, 0x6B, 0x47));
    private static readonly SolidColorBrush Empty = new(Color.FromArgb(0x22, 0xFF, 0xFF, 0xFF));
    private static readonly SolidColorBrush Hairline = new(Color.FromArgb(0x1C, 0xFF, 0xFF, 0xFF));
    private static readonly SolidColorBrush PartialBar = new(Color.FromArgb(0x22, 0xFF, 0xFF, 0xFF));

    public static readonly DependencyProperty IsCheckedProperty = DependencyProperty.Register(
        nameof(IsChecked), typeof(bool?), typeof(WormCheckBox),
        new FrameworkPropertyMetadata(null, OnIsCheckedChanged));

    public static readonly DependencyProperty IsEnabledForUseProperty = DependencyProperty.Register(
        nameof(IsEnabledForUse), typeof(bool), typeof(WormCheckBox),
        new FrameworkPropertyMetadata(true, OnIsEnabledForUseChanged));

    public bool? IsChecked
    {
        get => (bool?)GetValue(IsCheckedProperty);
        set => SetValue(IsCheckedProperty, value);
    }

    /// <summary>
    /// Whether the control accepts input. Distinct from IsEnabled so a blocked row
    /// can be shown greyed out but still display its tick state.
    /// </summary>
    public bool IsEnabledForUse
    {
        get => (bool)GetValue(IsEnabledForUseProperty);
        set => SetValue(IsEnabledForUseProperty, value);
    }

    public event EventHandler<CheckChangedEventArgs>? CheckedChanged;

    public WormCheckBox()
    {
        // 20x20 hit area, matching the macOS layout.
        Width = 20;
        Height = 20;
        Focusable = false;
        Cursor = Cursors.Hand;
        SnapsToDevicePixels = true;

        _box = new Border
        {
            Width = 14,
            Height = 14,
            CornerRadius = new CornerRadius(3.5),
            Background = Brushes.Transparent,
            BorderBrush = Hairline,
            BorderThickness = new Thickness(1),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center
        };

        _tick = new Path
        {
            Stroke = Brushes.White,
            StrokeThickness = 1.8,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            Opacity = 0,
            RenderTransform = new ScaleTransform(0.5, 0.5),
            RenderTransformOrigin = new Point(0.5, 0.5),
            Data = Geometry.Parse("M 2.2,5 L 4.8,7.6 L 10.6,1.4"),
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Width = 14,
            Height = 14
        };

        // Tri-state bar, matching TriStateBox in Components.swift.
        _partial = new Border
        {
            Width = 8,
            Height = 2,
            CornerRadius = new CornerRadius(1),
            Background = PartialBar,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            Opacity = 0
        };

        var grid = new Grid();
        grid.Children.Add(_box);
        grid.Children.Add(_tick);
        grid.Children.Add(_partial);
        Content = grid;

        MouseLeftButtonDown += (_, _) => Toggle();

        Refresh(animate: false);
    }

    private static void OnIsCheckedChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        => ((WormCheckBox)d).Refresh(animate: true);

    private static void OnIsEnabledForUseChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var cb = (WormCheckBox)d;
        var enabled = e.NewValue is true;
        cb.Opacity = enabled ? 1.0 : 0.4;
        cb.IsHitTestVisible = enabled;
        cb.Cursor = enabled ? Cursors.Hand : Cursors.Arrow;
    }

    private void Toggle()
    {
        if (!IsEnabledForUse) return;

        // A partially ticked category becomes fully ticked; a full one clears.
        IsChecked = IsChecked != true;

        CheckedChanged?.Invoke(this, new CheckChangedEventArgs(IsChecked == true));
    }

    private void Refresh(bool animate)
    {
        bool isOn = IsChecked == true;
        bool isPartial = IsChecked == null;

        _box.Background = isOn ? Accent : isPartial ? Empty : Brushes.Transparent;
        _box.BorderBrush = isOn ? Accent : Hairline;

        _partial.Opacity = isPartial ? 1 : 0;
        _tick.Opacity = isOn ? 1 : 0;

        if (!isOn || !animate) return;
        if (_tick.RenderTransform is not ScaleTransform scale) return;

        // The tick pops with springBouncy: 273.40 / 21.50, a 6.81% overshoot.
        scale.BeginAnimation(ScaleTransform.ScaleXProperty,
            WormMotion.SpringBouncy.From(0.5, 1.0));
        scale.BeginAnimation(ScaleTransform.ScaleYProperty,
            WormMotion.SpringBouncy.From(0.5, 1.0));
    }
}