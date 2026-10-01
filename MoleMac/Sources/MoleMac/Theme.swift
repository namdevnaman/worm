import SwiftUI
import MoleCore

/// Visual language for the app. One place, so a colour or radius never drifts
/// between two screens.
enum Theme {
    // A warm neutral ramp rather than macOS system grey: greys read as chrome,
    // and this app is a tool the user looks at while deciding what to delete.
    static let background = Color(red: 0.976, green: 0.969, blue: 0.957)
    static let surface = Color.white
    static let surfaceRaised = Color(red: 0.992, green: 0.989, blue: 0.984)
    static let hairline = Color(red: 0.871, green: 0.855, blue: 0.831)
    static let hairlineSoft = Color(red: 0.914, green: 0.902, blue: 0.882)

    static let ink = Color(red: 0.114, green: 0.106, blue: 0.102)
    static let inkSecondary = Color(red: 0.353, green: 0.333, blue: 0.310)
    /// Tertiary text: captions, paths, secondary metadata.
    ///
    /// Previously (0.573, 0.549, 0.518), which is only about 3.2:1 on the white
    /// background and read as washed-out grey at the 10-11pt sizes it is used at.
    /// WCAG AA wants 4.5:1 for body text, so this is roughly #6E6A64.
    static let inkTertiary = Color(red: 0.431, green: 0.416, blue: 0.392)

    static let accent = Color(red: 0.176, green: 0.353, blue: 0.255)
    static let accentSoft = Color(red: 0.882, green: 0.925, blue: 0.898)
    static let warn = Color(red: 0.706, green: 0.451, blue: 0.094)
    static let warnSoft = Color(red: 0.976, green: 0.937, blue: 0.847)
    static let danger = Color(red: 0.678, green: 0.216, blue: 0.188)
    static let dangerSoft = Color(red: 0.976, green: 0.906, blue: 0.898)
    static let info = Color(red: 0.212, green: 0.365, blue: 0.549)
    static let infoSoft = Color(red: 0.894, green: 0.925, blue: 0.957)

    static let radius: CGFloat = 8
    static let radiusLarge: CGFloat = 12

    static func riskColor(_ risk: Risk) -> Color {
        switch risk {
        case .regenerable: return accent
        case .reDownload: return warn
        case .userData: return danger
        case .unsafe: return inkTertiary
        }
    }

    static func riskSoft(_ risk: Risk) -> Color {
        switch risk {
        case .regenerable: return accentSoft
        case .reDownload: return warnSoft
        case .userData: return dangerSoft
        case .unsafe: return background
        }
    }

    static func severityColor(_ severity: HealthCheck.Severity) -> Color {
        switch severity {
        case .good: return accent
        case .notice: return warn
        case .warning: return danger
        }
    }

    static func severitySoft(_ severity: HealthCheck.Severity) -> Color {
        switch severity {
        case .good: return accentSoft
        case .notice: return warnSoft
        case .warning: return dangerSoft
        }
    }
}

/// A compact badge. Used for risk level, file counts, and status text.
struct Badge: View {
    let text: String
    var color: Color = Theme.inkSecondary
    var background: Color = Theme.background
    var symbol: String?

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

/// A horizontal proportion bar, used for category rollups and the disk gauge.
struct ProportionBar: View {
    let fraction: Double
    var color: Color = Theme.accent
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.hairlineSoft)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

/// Horizontal rule that matches the app's hairline weight.
struct Divider2: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}