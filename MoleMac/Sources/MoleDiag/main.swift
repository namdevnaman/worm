import Foundation
import MoleCore

let which = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "policy"
let t0 = Date()
switch which {
case "ps":
    let s = Date()
    let names = LivenessProbe.runningProcessNames()
    print("runningProcessNames: \(names?.count ?? -1) in \(String(format: "%.2f", Date().timeIntervalSince(s)))s")
case "lsofdir":
    let s = Date()
    let r = LivenessProbe.hasOpenHandle("/Users/namannamdev/Library/Caches")
    print("hasOpenHandle(dir): \(r) in \(String(format: "%.2f", Date().timeIntervalSince(s)))s")
case "scan":
    let scanner = ScanEngine()
    let cats: [CleanCategory] = CommandLine.arguments.count > 2
        ? CommandLine.arguments[2].split(separator: ",").map { CleanCategory(rawValue: String($0))! }
        : [.appCaches, .logs]
    let r = await scanner.scan(categories: cats)
    print("scan: \(r.targets.count) targets, \(ByteFormat.compact(r.targets.reduce(0){$0+$1.bytes})) in \(String(format: "%.2f", r.duration))s")
    print("blocked: \(r.blocked.count)")
    var reasons: [String:Int] = [:]
    for b in r.blocked { reasons[b.reason.rawValue, default: 0] += 1 }
    for (k,v) in reasons.sorted(by: { $0.value > $1.value }) { print("  blocked \(v)x \(k)") }
    print("top targets:")
    for t in r.targets.prefix(5) { print("  \(ByteFormat.compact(t.bytes)) \(t.path)") }
case "why":
    // Per-rule expansion report: which rules found nothing, and what blocked.
    let cats: [CleanCategory] = CommandLine.arguments.count > 2
        ? CommandLine.arguments[2].split(separator: ",").map { CleanCategory(rawValue: String($0))! }
        : [.appCaches]
    let engine = ScanEngine()
    for cat in cats {
        print("== \(cat.rawValue) ==")
        let r = await engine.scan(categories: [cat], includeBlocked: true)
        print("  targets=\(r.targets.count) blocked=\(r.blocked.count)")
        for b in r.blocked {
            print("  BLOCKED [\(b.reason.rawValue)] \(ByteFormat.compact(b.bytes)) \(b.path)")
        }
        for t in r.targets.prefix(4) {
            print("  ok      \(ByteFormat.compact(t.bytes)) \(t.path)")
        }
    }
case "roots":
    // Every root that actually exists on this Mac, so the allowed-root list can
    // be checked against reality instead of assumption.
    let fm = FileManager.default
    for url in SafetyPolicy.allowedRoots {
        let exists = fm.fileExists(atPath: url.path)
        let size = exists ? SizeMeasurer.measure(url.path, timeout: 1) : 0
        print("\(exists ? "exists " : "absent ") \(ByteFormat.compact(size))\t\(url.path)")
    }
case "orphans":
    let groups = OrphanDetector.findLeftovers(minAgeDays: 30)
    print("groups: \(groups.count)")
    var total: Int64 = 0
    for g in groups.prefix(14) {
        total += g.bytes
        print("  \(ByteFormat.compact(g.bytes))  \(g.displayName)  (\(g.leftovers.count) traces, \(g.reviewCount) need review)")
        for l in g.leftovers.prefix(4) {
            print("      [\(l.location.rawValue)/\(l.kind.rawValue)] \(ByteFormat.compact(l.bytes)) \(l.path)")
        }
    }
    print("total: \(ByteFormat.compact(total))")
case "traces":
    let id = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "com.wondershare.filmoramac"
    let traces = OrphanDetector.traces(forBundleID: id)
    print("traces for \(id): \(traces.count)")
    for t in traces {
        print("  \(t.needsReview ? "REVIEW " : "auto   ") [\(t.location.rawValue)] \(ByteFormat.compact(t.bytes)) \(t.path)")
    }
case "invtime":
    for pass in 1...2 {
        let t = Date()
        let apps = InstalledApps.all()
        print("pass \(pass): \(apps.count) apps in \(String(format: "%.2f", Date().timeIntervalSince(t)))s")
    }
    let t2 = Date()
    let ids = InstalledApps.bundleIDsInSearchPaths
    print("bundleIDsInSearchPaths: \(ids.count) in \(String(format: "%.2f", Date().timeIntervalSince(t2)))s")
case "stage":
    let t = Date()
    let apps = InstalledApps.all()
    print("apps: \(apps.count) in \(String(format: "%.2f", Date().timeIntervalSince(t)))s")
    let installed = Set(apps.map(\.id)).union(InstalledApps.bundleIDsInSearchPaths)
    print("installed set: \(installed.count)")
    for source in OrphanDetector.locations {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: source.root.path)) ?? []
        let stage = Date()
        var candidates = 0
        for name in entries where !name.hasPrefix(".") {
            if let bid = OrphanDetector.bundleID(forEntry: name), OrphanDetector.isCandidate(bid) {
                candidates += 1
                if !installed.contains(bid) {
                    _ = OrphanDetector.stillInstalled(bundleID: bid)
                }
            }
        }
        print("  \(source.location.rawValue): \(entries.count) entries, \(candidates) candidates, \(String(format: "%.2f", Date().timeIntervalSince(stage)))s")
    }
case "fullscan":
    let engine = ScanEngine()
    let t = Date()
    let r = await engine.scan()
    print("full scan: \(r.targets.count) targets \(ByteFormat.compact(r.targets.reduce(0){$0+$1.bytes})) blocked \(r.blocked.count) in \(String(format: "%.1f", Date().timeIntervalSince(t)))s")
case "whybig":
    // What is being withheld, and why. This is the gap-versus-expected check:
    // bytes the policy refuses must be explainable, not just absent.
    let engine = ScanEngine()
    let r = await engine.scan(includeBlocked: true)
    var byReason: [String: (Int64, Int)] = [:]
    for b in r.blocked {
        let cur = byReason[b.reason.rawValue] ?? (0, 0)
        byReason[b.reason.rawValue] = (cur.0 + b.bytes, cur.1 + 1)
    }
    print("cleanable: \(ByteFormat.compact(r.targets.reduce(0){$0+$1.bytes}))  blocked: \(ByteFormat.compact(r.blocked.reduce(0){$0+$1.bytes}))")
    for (k, v) in byReason.sorted(by: { $0.value.0 > $1.value.0 }) {
        print("  \(ByteFormat.compact(v.0).padding(toLength: 10, withPad: " ", startingAt: 0)) \(v.1)x \(k)")
    }
    print("top blocked:")
    for b in r.blocked.prefix(12) {
        print("  \(ByteFormat.compact(b.bytes)) [\(b.reason.rawValue)] \(b.path)")
    }
case "clivers":
    let home = Paths.home.path
    for rel in [".claude", ".gemini", ".opencode", ".local/share/opencode",
                ".local/share/claude", ".codex/config.toml", ".codex/auth.json"] {
        print("\(SafetyPolicy.verdict(for: "\(home)/\(rel)", probeLiveness: false)) <- \(rel)")
    }
case "codex":
    // Durable Codex CLI state must stay blocked; staging must be reachable.
    for p in ["/Users/namannamdev/.codex/config.toml",
              "/Users/namannamdev/.codex/auth.json",
              "/Users/namannamdev/.codex/sessions/abc.jsonl",
              "/Users/namannamdev/.codex/.tmp/bundled-marketplaces/x"] {
        print("\(SafetyPolicy.verdict(for: p, probeLiveness: false)) <- \(p)")
    }
case "probe":
    // Probe plumbing: which of the two process queries is failing.
    print("runningProcessNames: \(LivenessProbe.runningProcessNames()?.count.description ?? "nil")")
    if let names = LivenessProbe.runningProcessNames() {
        print("  sample: \(names.sorted().prefix(8).joined(separator: ", "))")
    }
case "which":
    // Does this path resolve as a user-cache path, and who owns it?
    for p in CommandLine.arguments.dropFirst(2) {
        let owner = LivenessProbe.ownerBundleID(for: p)
        print("userCache=\(LivenessProbe.isUserCachePath(p)) owner=\(owner ?? "nil") running=\(LivenessProbe.ownerProcessState(for: p).rawValue) \(p)")
    }
case "policy":
    let paths = ["/Users/namannamdev/Library/Caches/com.apple.Safari",
                 "/Users/namannamdev/Documents", "/Users/namannamdev/.cache/uv",
                 "/Users/namannamdev/Library/Caches/Google/Chrome",
                 "/Users/namannamdev/Library/Developer/Xcode/DerivedData",
                 "/Users/namannamdev/Library/Application Support/Slack/Cache"]
    let s = Date()
    for p in paths { print("  \(SafetyPolicy.verdict(for: p, probeLiveness: true)) <- \(p)") }
    print("6 policies in \(String(format: "%.3f", Date().timeIntervalSince(s)))s")
default: break
}
print("total \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
