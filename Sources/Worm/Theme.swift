import SwiftUI
import WormCore
import IOKit.pwr_mgt

/// Visual language for the app. One place, so a colour or radius never drifts
/// between two screens.
enum Theme {
    // Deep organic loam / soil dark palette with frosted glassmorphism
    static let darkBackground = Color(red: 0.082, green: 0.075, blue: 0.067) // #151311 deep loam soil
    static let darkSurface = Color(red: 0.125, green: 0.114, blue: 0.102) // #201D1A rich peat
    static let darkSurfaceRaised = Color(red: 0.165, green: 0.149, blue: 0.133) // #2A2622
    static let glassBackground = Color(red: 0.14, green: 0.12, blue: 0.11).opacity(0.72)
    static let glassBorder = Color.white.opacity(0.12)
    static let glassHighlight = Color.white.opacity(0.18)

    // Dynamic System/Dark/Light semantic colors
    static let background = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.082, green: 0.075, blue: 0.067, alpha: 1.0) // Deep rich loam
            : NSColor(red: 0.976, green: 0.969, blue: 0.957, alpha: 1.0) // Warm limestone
    }))

    static let surface = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.130, green: 0.118, blue: 0.106, alpha: 0.78) // Translucent dark peat glass
            : NSColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.82) // Translucent light porcelain glass
    }))

    static let surfaceRaised = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.175, green: 0.158, blue: 0.142, alpha: 0.88)
            : NSColor(red: 0.992, green: 0.989, blue: 0.984, alpha: 0.92)
    }))

    static let hairline = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.11)
            : NSColor(red: 0.871, green: 0.855, blue: 0.831, alpha: 0.90)
    }))

    static let hairlineSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(white: 1.0, alpha: 0.06)
            : NSColor(red: 0.914, green: 0.902, blue: 0.882, alpha: 0.80)
    }))

    static let ink = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.95, green: 0.93, blue: 0.91, alpha: 1.0) // Crisp light ink
            : NSColor(red: 0.114, green: 0.106, blue: 0.102, alpha: 1.0) // Deep dark ink
    }))

    static let inkSecondary = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.72, green: 0.69, blue: 0.66, alpha: 1.0)
            : NSColor(red: 0.353, green: 0.333, blue: 0.310, alpha: 1.0)
    }))

    static let inkTertiary = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.52, green: 0.49, blue: 0.46, alpha: 1.0)
            : NSColor(red: 0.396, green: 0.384, blue: 0.361, alpha: 1.0)
    }))

    // Warm organic earth/dirt palette for Worm
    static let accent = Color(red: 0.760, green: 0.420, blue: 0.280) // vibrant warm terracotta earth
    static let accentSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.35, green: 0.22, blue: 0.17, alpha: 0.45)
            : NSColor(red: 0.941, green: 0.898, blue: 0.871, alpha: 1.0)
    }))
    static let warmGlow = Color(red: 0.85, green: 0.52, blue: 0.35)
    static let warn = Color(red: 0.880, green: 0.580, blue: 0.180)
    static let warnSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.36, green: 0.28, blue: 0.12, alpha: 0.45)
            : NSColor(red: 0.976, green: 0.937, blue: 0.847, alpha: 1.0)
    }))
    static let danger = Color(red: 0.880, green: 0.320, blue: 0.280)
    static let dangerSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.40, green: 0.18, blue: 0.16, alpha: 0.45)
            : NSColor(red: 0.976, green: 0.906, blue: 0.898, alpha: 1.0)
    }))
    static let info = Color(red: 0.320, green: 0.560, blue: 0.800)
    static let infoSoft = Color(nsColor: NSColor(name: nil, dynamicProvider: { app in
        app.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(red: 0.16, green: 0.26, blue: 0.38, alpha: 0.45)
            : NSColor(red: 0.894, green: 0.925, blue: 0.957, alpha: 1.0)
    }))

    static let radius: CGFloat = 8
    static let radiusLarge: CGFloat = 12
    static let radiusPill: CGFloat = 20

    // Motion+ fluid spring animations
    static let springBouncy = Animation.spring(response: 0.38, dampingFraction: 0.65, blendDuration: 0.2)
    static let springSmooth = Animation.spring(response: 0.42, dampingFraction: 0.82, blendDuration: 0.2)
    static let springSnappy = Animation.spring(response: 0.26, dampingFraction: 0.72, blendDuration: 0.1)

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
        case .good: return Color(red: 0.35, green: 0.78, blue: 0.55)
        case .notice: return warn
        case .warning: return danger
        }
    }

    static func severitySoft(_ severity: HealthCheck.Severity) -> Color {
        switch severity {
        case .good: return Color(red: 0.20, green: 0.45, blue: 0.30).opacity(0.35)
        case .notice: return warnSoft
        case .warning: return dangerSoft
        }
    }

    enum Mode: String, CaseIterable, Identifiable {
        case system = "System"
        case dark = "Dark"
        case light = "Light"

        var id: String { rawValue }
    }

    // Dynamic semantic colors supporting both Dark and Light modes
    static func bg(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? darkBackground : Color(red: 0.976, green: 0.969, blue: 0.957)
    }

    static func surf(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? darkSurface : Color.white
    }

    static func surfRaised(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? darkSurfaceRaised : Color(red: 0.992, green: 0.989, blue: 0.984)
    }

    static func textInk(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? Color(red: 0.95, green: 0.93, blue: 0.91) : Color(red: 0.114, green: 0.106, blue: 0.102)
    }

    static func textSec(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? Color(red: 0.72, green: 0.69, blue: 0.66) : Color(red: 0.353, green: 0.333, blue: 0.310)
    }

    static func textTert(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? Color(red: 0.52, green: 0.49, blue: 0.46) : Color(red: 0.396, green: 0.384, blue: 0.361)
    }

    static func borderLine(for scheme: ColorScheme, mode: Mode = .system) -> Color {
        let isDark = (mode == .dark) || (mode == .system && scheme == .dark)
        return isDark ? Color.white.opacity(0.11) : Color(red: 0.871, green: 0.855, blue: 0.831)
    }

    // Distinct organic earthy signature accent color per screen/tab
    static func tabAccent(for tab: String) -> Color {
        switch tab.lowercased() {
        case "clean":
            return Color(red: 0.76, green: 0.42, blue: 0.28) // Rich terracotta mud
        case "leftovers":
            return Color(red: 0.82, green: 0.48, blue: 0.22) // Golden loam
        case "apps":
            return Color(red: 0.68, green: 0.44, blue: 0.52) // Earthy clay rose
        case "disk":
            return Color(red: 0.45, green: 0.58, blue: 0.42) // Forest moss peat
        case "status":
            return Color(red: 0.38, green: 0.58, blue: 0.68) // Riverbed silt
        case "settings":
            return Color(red: 0.62, green: 0.52, blue: 0.42) // Umber bedrock
        default:
            return accent
        }
    }
}

/// Interactive button style with a micro-scale bounce and tactile feel inspired by Motion+
struct FluidButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(Theme.springSnappy, value: configuration.isPressed)
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
                    .animation(Theme.springSmooth, value: fraction)
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

/// Frosted glass background card modifier with subtle border highlight
struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 12
    var strokeColor: Color = Theme.hairline

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    VisualEffectBlur(material: .sidebar, blendingMode: .withinWindow)
                    Theme.surface
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 12, strokeColor: Color = Theme.hairline) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, strokeColor: strokeColor))
    }
}

/// Native macOS blur backing
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// A delightful animated earthworm that wiggles, burrows into soil, and digs
struct DiggingWormAnimation: View {
    var isDigging: Bool = true
    var size: CGFloat = 64

    private static let wormPink = Color(red: 0.90, green: 0.48, blue: 0.38)
    private static let saddleColor = Color(red: 0.98, green: 0.72, blue: 0.62)
    private static let soilColor1 = Color(red: 0.45, green: 0.28, blue: 0.18)
    private static let soilColor2 = Color(red: 0.62, green: 0.38, blue: 0.24)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = elapsed * 4.5

            Canvas { context, sz in
                let w = sz.width
                let h = sz.height
                let midY = h / 2
                let segments = 7
                let step = (w - 14) / CGFloat(segments)

                // Ejected earth clumps and lively flying soil pebbles
                for p in 0..<6 {
                    let pAngle = Double(p) * 0.95 + elapsed * 3.0
                    let dist = 5.0 + Double(p % 3) * 3.5
                    let pX = (w * 0.22) + cos(pAngle) * dist
                    let pY = midY + sin(pAngle) * dist * 0.7
                    let pRadius: CGFloat = (p % 2 == 0) ? 2.8 : 2.0
                    let pRect = CGRect(x: pX - pRadius/2, y: pY - pRadius/2, width: pRadius, height: pRadius)
                    context.fill(Path(ellipseIn: pRect), with: .color((p % 2 == 0) ? Self.soilColor1 : Self.soilColor2))
                }

                // Smooth burrowing body segments with lively sinusoidal wave
                for i in 0..<segments {
                    let x = 8.0 + CGFloat(i) * step
                    let wave = sin(phase + Double(i) * 0.75) * (h * 0.20)
                    let y = midY + CGFloat(wave)
                    let radius: CGFloat = (i == 0) ? (h * 0.25) : ((i == segments - 1) ? (h * 0.15) : (h * 0.20))

                    let segRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: segRect), with: .color(Self.wormPink))

                    // Clitellum / warm saddle band on segment 2
                    if i == 2 {
                        let saddleRect = CGRect(x: x - radius * 1.25, y: y - radius * 1.25, width: radius * 2.5, height: radius * 2.5)
                        context.stroke(Path(ellipseIn: saddleRect), with: .color(Self.saddleColor), lineWidth: 2.2)
                    }
                }

                // Head details: Eye and cute curious gaze
                let headX = 8.0
                let headY = midY + CGFloat(sin(phase) * (h * 0.20))
                let eyeRect = CGRect(x: headX - 2.5, y: headY - 3.5, width: 3.5, height: 3.5)
                context.fill(Path(ellipseIn: eyeRect), with: .color(.black.opacity(0.85)))
                let sparkle = CGRect(x: headX - 2.0, y: headY - 3.0, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: sparkle), with: .color(.white))
            }
            .frame(width: size, height: size * 0.75)
        }
    }
}

/// Official app logo badge icon for the top navbar with live animated mascot glow
struct WormBrandmarkIcon: View {
    var tintColor: Color = Theme.accent

    // Statically cached so disk/bundle is never hit in render passes
    static let sharedIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "WormAppIcon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let url = Bundle.main.url(forResource: "AppIcon_512", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        if let appImg = NSApp?.applicationIconImage, appImg.isValid {
            return appImg
        }
        // Embedded 64x64 crisp PNG asset guarantee
        let b64 = "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"
        if let data = Data(base64Encoded: b64), let img = NSImage(data: data) {
            return img
        }
        return NSWorkspace.shared.icon(for: .application)
    }()

    @StateObject private var isPulsing = Box(false)

    var body: some View {
        ZStack {
            // Frosted glowing highlight pod
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tintColor.opacity(0.25), tintColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(tintColor.opacity(0.40), lineWidth: 1)
                )
                .shadow(color: tintColor.opacity(0.20), radius: 5, y: 1)

            // Official high-resolution macOS Worm App Icon (Hardware accelerated)
            Image(nsImage: Self.sharedIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5.5, style: .continuous))
                .scaleEffect(isPulsing.value ? 1.05 : 0.98)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isPulsing.value)
        }
        .frame(width: 28, height: 28)
        .onAppear {
            isPulsing.value = true
        }
    }
}

/// An animated earthworm that munches and eats junk files & soil particles
struct EatingWormAnimation: View {
    var size: CGFloat = 80

    private static let wormPink = Color(red: 0.90, green: 0.48, blue: 0.38)
    private static let saddleColor = Color(red: 0.98, green: 0.72, blue: 0.62)
    private static let mouthColor = Color(red: 0.32, green: 0.10, blue: 0.08)
    private static let crumbColor1 = Color(red: 0.52, green: 0.32, blue: 0.22)
    private static let crumbColor2 = Color(red: 0.78, green: 0.48, blue: 0.28)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let chew = sin(elapsed * 12.0)
            let wiggle = sin(elapsed * 5.0)

            Canvas { context, sz in
                let w = sz.width
                let h = sz.height
                let midY = h / 2

                // Flying soil crumbs & junk bits flying into mouth
                for i in 0..<5 {
                    let dIndex = Double(i)
                    let crumbOffset = (elapsed * 45.0 + dIndex * 14.0).truncatingRemainder(dividingBy: 36.0)
                    let crumbX = (w * 0.86) - CGFloat(crumbOffset)
                    let sinVal = sin(dIndex * 1.3 + elapsed * 3.5)
                    let crumbY = midY + CGFloat(sinVal) * (h * 0.20)
                    let crumbSize: CGFloat = (i % 2 == 0) ? 3.5 : 2.5
                    let crumbRect = CGRect(x: crumbX, y: crumbY, width: crumbSize, height: crumbSize)
                    context.fill(Path(ellipseIn: crumbRect), with: .color((i % 2 == 0) ? Self.crumbColor1 : Self.crumbColor2))
                }

                // Worm segmented body
                let bodySegments = 6
                for i in 0..<bodySegments {
                    let x = (w * 0.48) - CGFloat(i * 10)
                    let y = midY + CGFloat(sin(Double(i) * 0.85 + wiggle) * (h * 0.16))
                    let radius: CGFloat = (i == 0) ? 9.5 : (8.5 - CGFloat(i) * 0.6)
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Self.wormPink))

                    // Saddle band
                    if i == 2 {
                        let saddleRect = CGRect(x: x - radius * 1.25, y: y - radius * 1.25, width: radius * 2.5, height: radius * 2.5)
                        context.stroke(Path(ellipseIn: saddleRect), with: .color(Self.saddleColor), lineWidth: 2.0)
                    }
                }

                // Big chewing mouth (animates open and shut munching)
                let mouthOpen = max(3.0, CGFloat(7.0 + chew * 5.0))
                let mouthX = (w * 0.52)
                let mouthY = midY
                let mouthRect = CGRect(x: mouthX - 2.0, y: mouthY - mouthOpen / 2, width: 7.5, height: mouthOpen)
                context.fill(Path(ellipseIn: mouthRect), with: .color(Self.mouthColor))

                // Expressive happy eye
                let eyeY = midY - 6.0
                let eyeRect = CGRect(x: mouthX - 5.5, y: eyeY, width: 3.5, height: 3.5)
                context.fill(Path(ellipseIn: eyeRect), with: .color(.black.opacity(0.85)))
                // Eye twinkle
                let twinkleRect = CGRect(x: mouthX - 5.0, y: eyeY + 0.5, width: 1.2, height: 1.2)
                context.fill(Path(ellipseIn: twinkleRect), with: .color(.white))
            }
            .frame(width: size, height: size * 0.55)
        }
    }
}

// MARK: - Keep Screen On / Caffeinate Manager
@MainActor
final class KeepScreenOnManager: ObservableObject {
    static let shared = KeepScreenOnManager()

    @Published private(set) var activeMinutes: Int? = nil // nil = off, 0 = indefinite
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?

    private init() {}

    func activate(minutes: Int) {
        deactivate()
        activeMinutes = minutes

        let reason = "Worm keeping display active" as CFString
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )

        if result == kIOReturnSuccess, minutes > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.deactivate()
                }
            }
        }
    }

    func deactivate() {
        timer?.invalidate()
        timer = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        activeMinutes = nil
    }
}

// MARK: - Clean Screen Controller
@MainActor
final class CleanScreenController {
    private static var blackoutWindows: [NSWindow] = []

    static func show() {
        hide()
        for screen in NSScreen.screens {
            let win = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            win.level = .screenSaver
            win.backgroundColor = .black
            win.isOpaque = true
            win.ignoresMouseEvents = false

            let hosting = NSHostingView(rootView: CleanScreenOverlayView {
                hide()
            })
            win.contentView = hosting
            win.makeKeyAndOrderFront(nil)
            blackoutWindows.append(win)
        }
        NSCursor.hide()
    }

    static func hide() {
        NSCursor.unhide()
        for win in blackoutWindows {
            win.orderOut(nil)
        }
        blackoutWindows.removeAll()
    }
}

struct CleanScreenOverlayView: View {
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 20) {
                EatingWormAnimation(size: 90)

                Text("Clean Screen Mode Active")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Wipe down your display safely.\nPress Esc or click anywhere to exit.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .multilineTextAlignment(.center)

                Button("Exit Clean Screen") {
                    onExit()
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accent)
                )
                .padding(.top, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onExit()
        }
    }
}

/// Disables standard AppKit blue focus rings on enclosing controls
struct WithoutFocusRing: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = FocusClearView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        FocusClearView.clearFocusRings(in: nsView.superview)
    }

    final class FocusClearView: NSView {
        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            Self.clearFocusRings(in: superview)
        }

        static func clearFocusRings(in view: NSView?) {
            guard let view else { return }
            view.focusRingType = .none
            for sub in view.subviews {
                sub.focusRingType = .none
                if let control = sub as? NSControl {
                    control.focusRingType = .none
                }
            }
            if let sup = view.superview {
                sup.focusRingType = .none
            }
        }
    }
}