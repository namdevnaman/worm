import AppKit
import SwiftUI
import WormCore

/// A diagnostic run, started with `Worm.app/Contents/MacOS/Worm --selftest`,
/// that answers the question that cannot be settled by inspection or by the
/// core test suite: **does driving the navbar tabs abort the process?**
///
/// Why this is a self-test and not a unit test. The failure it guards is a
/// SwiftUI view-graph type mismatch — `AG::Graph::value_set` precondition
/// failure, reached from `ViewGraph.beginNextUpdate` under
/// `+[NSAnimationContext runAnimationGroup:]`. It surfaces as
/// `EXC_CRASH / SIGABRT`, not a thrown error, so no assertion can observe it
/// and nothing can catch it. The only honest signal is whether the process is
/// still alive afterwards, which is exactly what an exit code gives us.
///
/// It also cannot run under a test framework here: this project's Swift Testing
/// and XCTest macro plugins ship with Xcode rather than the Command Line Tools,
/// so `swift test` does not build in this toolchain at all. The Windows build
/// already uses this shape (`--selftest`, exit code), so the two platforms
/// agree rather than diverging.
///
/// Exit code is 0 when every probe survives. A regression aborts with SIGABRT
/// (134) partway through, which is the failure this exists to catch.
enum SelfTest {

    /// Pump the main run loop. The tab swap in `RootView` is scheduled with
    /// `DispatchQueue.main.asyncAfter`, so the only way to make it run is to let
    /// the run loop turn — there is no synchronous path to it.
    @MainActor
    private static func pump(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        // `run(mode:before:)` returns immediately when the run loop has no
        // sources or timers attached, which turns this into a busy-wait that
        // pins a core and made the suite take minutes. `run(until:)` sleeps when
        // idle, which is what lets the scheduled `asyncAfter` swaps fire without
        // starving them of CPU.
        while Date() < deadline {
            RunLoop.main.run(until: deadline)
        }
    }

    /// Host `RootView` offscreen. An `NSWindow` that is never ordered front still
    /// performs real layout passes, which is what the faulting frame requires.
    @MainActor
    private static func makeWindow() -> (window: NSWindow, store: AppStore) {
        let store = AppStore()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 720),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(
            rootView: RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                .focusEffectDisabled()
        )
        window.layoutIfNeeded()
        return (window, store)
    }

    /// `filter` narrows the run to probes whose label contains the argument,
    /// which is what makes the loop usable during a fix. `quick` runs only the
    /// probes that reproduce the original abort, in a few seconds, so it can
    /// gate a build; the full suite renders every tab synchronously and is for
    /// deliberate use rather than every commit.
    @MainActor
    static func run(filter: String? = nil, quick: Bool = false) -> Int32 {
        let effectiveFilter: String? = if quick { filter ?? "regression" } else { filter }
        var lines: [String] = []
        var failures = 0

        func emit(_ text: String) {
            lines.append(text)
            FileHandle.standardOutput.write(Data((text + "\n").utf8))
        }

        // Heartbeat on stderr, which is unbuffered. stdout is block-buffered when
        // redirected, so a hang with buffered output is indistinguishable from a
        // hang before the first line.
        FileHandle.standardError.write(Data("[selftest] start\n".utf8))

        var ran = 0
        func probe(_ label: String, _ body: () -> Void) {
            if let effectiveFilter, !label.localizedCaseInsensitiveContains(effectiveFilter) { return }
            emit("--- \(label)")
            // Timed, because "the guard takes four minutes" is itself a bug in
            // the guard: nobody runs it, and a regression ships.
            let started = Date()
            body()
            emit(String(format: "pass  %@  (%.1fs)", label, Date().timeIntervalSince(started)))
            ran += 1
        }

        emit("Worm self-test  \(ISO8601DateFormatter().string(from: Date()))")
        emit(String(repeating: "=", count: 68))
        emit("")

        // One host for every probe. A fresh AppStore per probe re-ran
        // RootView's `.task`, which kicks off a full disk scan — serially, five
        // times over, which is what made the first version of this harness hang.
        //
        // Reusing one host is also the more faithful reproduction: the initial
        // scan is still in flight and still publishing while the tabs are
        // switched, which is exactly the startup window a user clicks through.
        let host = makeWindow()
        defer { host.window.close() }
        pump(0.4)

        // Every tab, selected in order, each allowed to settle.
        probe("all tabs selectable, settling between each") {
            for tab in ["clean", "leftovers", "apps", "disk", "status", "settings"] {
                host.store.activeTab = tab
                host.window.layoutIfNeeded()
                pump(0.35)
                host.window.layoutIfNeeded()
            }
        }

        // The reported trigger: transitions overlapping, because the view-type
        // swap is scheduled on a timer rather than applied on click.
        probe("rapid switching, transitions left to overlap") {
            let order = ["apps", "disk", "leftovers", "settings", "clean", "status"]
            for _ in 0..<3 {
                for tab in order {
                    host.store.activeTab = tab
                    pump(0.05)   // shorter than the 0.22s swap delay
                }
            }
            pump(0.7)
            host.window.layoutIfNeeded()
        }

        // The same overlaps wrapped in an animation group, which is the frame the
        // crash report shows directly above the faulting call.
        probe("overlapping transitions inside an animation group") {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                for tab in ["disk", "apps", "settings", "leftovers"] {
                    host.store.activeTab = tab
                    host.window.layoutIfNeeded()
                }
            }
            pump(0.7)
            host.window.layoutIfNeeded()
        }

        // Transitioning while the window resizes, which nests a layout pass
        // inside the animation context.
        probe("tab switch concurrent with window resize") {
            for width in [1180.0, 1000.0, 1320.0, 1040.0] {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    host.store.activeTab = width > 1200 ? "apps" : "disk"
                    host.window.setContentSize(NSSize(width: width, height: 720))
                    host.window.layoutIfNeeded()
                }
                pump(0.25)
            }
        }

        // The brandmark path drives a transition from two places at once: it
        // calls the transition helper and publishes `activeTab`, which the view
        // also observes. Both land in the same runloop turn.
        probe("brandmark path publishes activeTab while transitioning") {
            for _ in 0..<8 {
                host.store.activeTab = "clean"
                host.store.activeTab = "status"
                host.window.layoutIfNeeded()
                pump(0.05)
                host.window.layoutIfNeeded()
                pump(0.3)
            }
        }

        // Back-to-back alternation, the shape a user produces by clicking the
        // same two tabs in frustration after the first click appears to do
        // nothing.
        probe("alternating tabs as fast as the run loop allows") {
            for i in 0..<8 {
                host.store.activeTab = i.isMultiple(of: 2) ? "settings" : "apps"
                host.window.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            pump(0.8)
        }

        // Heavy stress on the transition queue. Every click schedules a closure
        // that swaps the Group's concrete view type, and nothing cancels the ones
        // already pending — so this deliberately builds a deep backlog of pending
        // swaps that all land inside each other's animation contexts.
        probe("sustained overlapping swaps from a backlog") {
            for _ in 0..<2 {
                for tab in ["apps", "disk", "settings", "leftovers", "clean", "status"] {
                    host.store.activeTab = tab
                }
                pump(0.3)
                host.window.layoutIfNeeded()
            }
        }

        // Same, but the swaps land from the run loop rather than synchronously,
        // which is what a real click does.
        probe("swaps dispatched asynchronously while layout runs") {
            for round in 0..<12 {
                let tab = round.isMultiple(of: 2) ? "apps" : "settings"
                DispatchQueue.main.async { host.store.activeTab = tab }
                host.window.layoutIfNeeded()
                RunLoop.main.run(until: Date().addingTimeInterval(0.03))
            }
            pump(1.0)
            host.window.layoutIfNeeded()
        }

        // Two hosting views observing one store, which is the app's real shape:
        // the main window and the menu bar panel share `store`.
        probe("regression: two hosting views sharing one store") {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            panel.contentView = NSHostingView(
                rootView: MenuBarPanel().environmentObject(host.store))
            panel.layoutIfNeeded()
            defer { panel.close() }

            for round in 0..<10 {
                host.store.activeTab = round.isMultiple(of: 3) ? "status" : "clean"
                host.window.layoutIfNeeded()
                panel.layoutIfNeeded()
                pump(0.12)
                panel.layoutIfNeeded()
                host.window.layoutIfNeeded()
            }
            pump(0.5)
        }

        // ── Isolation probes ──────────────────────────────────────────────
        // Which ingredient is load-bearing? Each strips one variable out of the
        // failing probe to find the minimum that still aborts.

        // A: two hosting views, but no tab change at all.
        probe("regression: isolate A: two views, no tab switching") {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.contentView = NSHostingView(
                rootView: MenuBarPanel().environmentObject(host.store))
            panel.layoutIfNeeded()
            defer { panel.close() }
            for _ in 0..<6 {
                host.window.layoutIfNeeded()
                panel.layoutIfNeeded()
                pump(0.02)
            }
        }

        // B and C below are bisection artefacts, not guards. They earn their
        // place by recording *why* the fix works — one view cannot abort, and a
        // trivial second view cannot either, so it takes the panel itself — and
        // they are kept to a token iteration count because they render every
        // tab synchronously and are by far the slowest probes here.

        // B: one view, tab switching only — the main window alone.
        probe("isolate B: one view, tab switching only") {
            for _ in 0..<2 {
                host.store.activeTab = "status"
                host.window.layoutIfNeeded()
                pump(0.25)
                host.store.activeTab = "clean"
                host.window.layoutIfNeeded()
                pump(0.25)
            }
        }

        // C: two views, but the second hosts a trivial view rather than the
        // real panel, isolating "two graphs" from "the panel's own content".
        probe("isolate C: two views, second one trivial") {
            let other = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            other.contentView = NSHostingView(
                rootView: Text("hello").environmentObject(host.store))
            other.layoutIfNeeded()
            defer { other.close() }
            for round in 0..<4 {
                host.store.activeTab = round.isMultiple(of: 2) ? "status" : "clean"
                host.window.layoutIfNeeded()
                other.layoutIfNeeded()
                pump(0.15)
                other.layoutIfNeeded()
                host.window.layoutIfNeeded()
            }
        }

        // D: two views hosting the same panel twice.
        probe("regression: isolate D: two panels, no main window tabs") {
            func makePanel() -> NSWindow {
                let w = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                w.contentView = NSHostingView(
                    rootView: MenuBarPanel().environmentObject(host.store))
                w.layoutIfNeeded()
                return w
            }
            let a = makePanel(); let b = makePanel()
            defer { a.close(); b.close() }
            for round in 0..<6 {
                host.store.activeTab = round.isMultiple(of: 2) ? "status" : "clean"
                a.layoutIfNeeded()
                b.layoutIfNeeded()
                pump(0.1)
            }
        }

        // The fix for the crash changed `emptySnapshot()` to do no I/O, which is
        // only safe if real values still arrive afterwards. Assert that directly,
        // rather than trusting a screenshot: the panel starts from the empty
        // snapshot and is filled in by its `.task`.
        probe("regression: metrics still populate after the empty snapshot change") {
            let empty = SystemMetrics.emptySnapshot()
            // The empty snapshot must be genuinely inert, or it is the bug again.
            precondition(empty.disk.totalBytes == 0,
                         "emptySnapshot still reports disk totals — it is doing I/O")
            precondition(empty.memory.totalBytes == 0,
                         "emptySnapshot still reports memory totals — it is doing I/O")
            precondition(empty.loadAverage.isEmpty,
                         "emptySnapshot still reports load average — it is doing I/O")
            precondition(empty.batteryHealth == nil,
                         "emptySnapshot still spawns ioreg for battery health")
            precondition(empty.gpu == nil && empty.fan == nil,
                         "emptySnapshot still queries GPU or fan state")
            precondition(empty.cpuTemperatureCelsius == nil,
                         "emptySnapshot still reads CPU temperature")

            // And the real snapshot must still work, with a plausible disk.
            let real = SystemMetrics.snapshot()
            precondition(real.disk.totalBytes > 0,
                         "snapshot() no longer reports a disk — the panel would show zeros")
            precondition(real.memory.totalBytes > 0,
                         "snapshot() no longer reports memory")
        }

        // Any probe that threw would land here; a crash aborts before it does.
        do {
            try FileManager.default.createDirectory(
                at: Paths.logDir, withIntermediateDirectories: true)
            let report = lines.joined(separator: "\n") + "\n"
            try report.write(
                to: Paths.logDir.appendingPathComponent("selftest.txt"),
                atomically: true, encoding: .utf8)
            emit("")
            emit("log: \(Paths.logDir.appendingPathComponent("selftest.txt").path)")
        } catch {
            failures += 1
            emit("FAIL  could not write selftest.log — \(error.localizedDescription)")
        }

        emit("")
        emit("probes run: \(ran)")
        emit(failures == 0 ? "OK — no abort" : "\(failures) probe(s) failed")
        return failures == 0 ? 0 : 1
    }
}