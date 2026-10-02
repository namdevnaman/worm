using System;
using System.Globalization;

namespace Worm.Core;

/// <summary>
/// Shared number and byte formatting so every screen rounds and abbreviates
/// identically to the macOS app. Keeping this in one place is what stops the
/// Settings view and the Clean view disagreeing about whether 1.5 GB is "1.5 GB"
/// or "1.50 GB".
/// </summary>
public static class WormFormat
{
    private static readonly string[] Suffixes = { "B", "KB", "MB", "GB", "TB", "PB" };

    /// <summary>
    /// Compact size with a stable precision per magnitude: bytes are whole,
    /// KB two decimals, and above that one. Matches the macOS compact() output
    /// closely enough that the two apps read identically.
    /// </summary>
    public static string Bytes(long bytes)
    {
        if (bytes < 0) return "-" + Bytes(-bytes);
        if (bytes < 1024) return $"{bytes} B";

        double value = bytes;
        int unit = 0;

        while (value >= 1024 && unit < Suffixes.Length - 1)
        {
            value /= 1024;
            unit++;
        }

        var format = unit switch
        {
            1 => "0.##",   // KB
            2 => "0.#",    // MB
            _ => "0.#"     // GB and above
        };

        return value.ToString(format, CultureInfo.InvariantCulture) + " " + Suffixes[unit];
    }

    /// <summary>Tabular-friendly percentage, always one decimal place.</summary>
    public static string Percent(double fraction)
        => (fraction * 100).ToString("0.0", CultureInfo.InvariantCulture) + "%";

    public static string Uptime(TimeSpan uptime)
    {
        if (uptime.TotalDays >= 1)
            return $"{(int)uptime.TotalDays}d {uptime.Hours}h";
        if (uptime.TotalHours >= 1)
            return $"{(int)uptime.TotalHours}h {uptime.Minutes}m";
        return $"{uptime.Minutes}m";
    }

    public static string Age(DateTime createdUtc)
    {
        var days = (DateTime.UtcNow - createdUtc).TotalDays;
        if (days < 1) return "today";
        if (days < 2) return "1 day";
        if (days < 365) return $"{(int)days} days";
        var years = days / 365.0;
        return years < 2 ? "1 year" : $"{(int)years} years";
    }
}
