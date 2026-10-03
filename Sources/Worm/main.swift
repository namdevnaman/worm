import AppKit

// Explicit entry point rather than `@main` on WormApp, so the `--selftest`
// diagnostic can run before any UI exists. Mirrors the Windows build, which
// checks `e.Args` in its startup path and calls `Environment.Exit`.
if let selftestIndex = CommandLine.arguments.firstIndex(where: {
    $0.caseInsensitiveCompare("--selftest") == .orderedSame
}) {
    // `--selftest two hosting` runs only the probes whose label matches, so a
    // single regression can be re-run in seconds.
    var filter: String?
    let next = selftestIndex + 1
    if next < CommandLine.arguments.count,
       !CommandLine.arguments[next].hasPrefix("--") {
        filter = CommandLine.arguments[next]
    }
    let quick = CommandLine.arguments.contains("--quick")
    exit(MainActor.assumeIsolated { SelfTest.run(filter: filter, quick: quick) })
}

WormApp.main()