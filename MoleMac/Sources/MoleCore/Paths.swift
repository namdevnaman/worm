import Foundation

/// Central place for filesystem roots. Every path in the app is expanded
/// through here so `~`, `getconf DARWIN_USER_CACHE_DIR` and friends resolve
/// once, consistently, on every code path.
public enum Paths {
    public static var home: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    public static var library: URL { home.appendingPathComponent("Library", isDirectory: true) }
    public static var caches: URL { library.appendingPathComponent("Caches", isDirectory: true) }
    public static var logs: URL { library.appendingPathComponent("Logs", isDirectory: true) }
    public static var appSupport: URL { library.appendingPathComponent("Application Support", isDirectory: true) }
    public static var containers: URL { library.appendingPathComponent("Containers", isDirectory: true) }
    public static var groupContainers: URL { library.appendingPathComponent("Group Containers", isDirectory: true) }
    public static var trash: URL { home.appendingPathComponent(".Trash", isDirectory: true) }
    public static var developer: URL { library.appendingPathComponent("Developer", isDirectory: true) }

    public static var configDir: URL { home.appendingPathComponent(".config/mole", isDirectory: true) }

    /// `getconf DARWIN_USER_CACHE_DIR` — normally `~/Library/Caches`, but it can
    /// be redirected per-user. Caches swept by path must use this, not a guess.
    public static var darwinUserCacheDir: URL {
        if let out = try? run("/usr/bin/getconf", ["DARWIN_USER_CACHE_DIR"], timeout: 3),
           out.status == 0 {
            let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.hasPrefix("/") {
                return URL(fileURLWithPath: trimmed, isDirectory: true)
            }
        }
        return caches
    }

    public static var darwinUserTempDir: URL {
        if let out = try? run("/usr/bin/getconf", ["DARWIN_USER_TEMP_DIR"], timeout: 3),
           out.status == 0 {
            let trimmed = out.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed.hasPrefix("/") {
                return URL(fileURLWithPath: trimmed, isDirectory: true)
            }
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    public static var logDir: URL { logs.appendingPathComponent("MoleMac", isDirectory: true) }
    public static var deletionLog: URL { logDir.appendingPathComponent("deletions.tsv") }
    public static var historyLog: URL { logDir.appendingPathComponent("history.jsonl") }

    /// Expand a rule-authored path expression. Supports `~`, `~relative` for
    /// DENO_DIR-style variables, and environment overrides.
    public static func expand(_ expression: String, env: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        var s = expression
        if s == "~" {
            s = home.path
        } else if s.hasPrefix("~/") {
            s = home.path + s.dropFirst(1)
        }
        for (key, value) in env where !value.isEmpty && value.hasPrefix("/") {
            s = s.replacingOccurrences(of: "$\(key)", with: value)
        }
        return URL(fileURLWithPath: s, isDirectory: true)
    }

    @discardableResult
    static func run(_ launchPath: String, _ args: [String], timeout: TimeInterval) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()

        // Read both pipes concurrently: a producer that fills a pipe buffer would
        // otherwise deadlock against waitUntilExit. `timeout` is a hard
        // ceiling, mirroring Mole's `_run_with_timeout` contract.
        let collector = PipeCollector()
        out.fileHandleForReading.readabilityHandler = { collector.append(out: $0.availableData) }
        err.fileHandleForReading.readabilityHandler = { collector.append(err: $0.availableData) }

        let deadlineTimer = DispatchWorkItem {
            if process.isRunning { process.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: deadlineTimer)
        process.waitUntilExit()
        deadlineTimer.cancel()
        out.fileHandleForReading.readabilityHandler = nil
        err.fileHandleForReading.readabilityHandler = nil
        collector.append(out: out.fileHandleForReading.availableData)
        collector.append(err: err.fileHandleForReading.availableData)

        let (stdoutData, stderrData) = collector.drain()
        return CommandResult(
            status: process.terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? "",
            timedOut: process.terminationReason == .uncaughtSignal
        )
    }
}

/// Lock-guarded accumulator for concurrent pipe reads.
private final class PipeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var out = Data()
    private var err = Data()

    func append(out data: Data) {
        lock.lock(); out.append(data); lock.unlock()
    }

    func append(err data: Data) {
        lock.lock(); err.append(data); lock.unlock()
    }

    func drain() -> (Data, Data) {
        lock.lock(); defer { lock.unlock() }
        return (out, err)
    }
}

struct CommandResult {
    let status: Int32
    let stdout: String
    let stderr: String
    var timedOut: Bool = false
}

public enum ByteFormat {
    public static func string(_ bytes: Int64) -> String {
        if bytes <= 0 { return "Zero KB" }
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        return f.string(fromByteCount: bytes)
    }

    /// Compact form used in list rows: `5.59 GB`.
    public static func compact(_ bytes: Int64) -> String {
        let units: [(String, Double)] = [
            ("TB", 1024.0 * 1024 * 1024 * 1024),
            ("GB", 1024.0 * 1024 * 1024),
            ("MB", 1024.0 * 1024),
            ("KB", 1024.0),
        ]
        for (suffix, divisor) in units {
            if Double(bytes) >= divisor {
                return String(format: "%.2f %@", Double(bytes) / divisor, suffix)
            }
        }
        return "\(max(bytes, 0)) bytes"
    }
}