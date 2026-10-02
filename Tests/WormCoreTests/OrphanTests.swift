import Foundation
import Testing
@testable import WormCore

/// Leftover detection is the newest and least proven part of the engine, and
/// its failure modes are the worst kind: reporting a live app's data as an
/// orphan, or grouping unrelated folders under one app name.
@Suite("Leftover detection")
struct OrphanDetectorTests {

    @Test("Trace suffixes collapse to the owning bundle ID")
    func suffixStripping() {
        // Without this, `com.vendor.app.binarycookies` becomes its own app and
        // the trace never groups with its siblings.
        #expect(OrphanDetector.bundleID(forEntry: "com.vendor.app")
                == "com.vendor.app")
        #expect(OrphanDetector.bundleID(forEntry: "com.vendor.app.plist")
                == "com.vendor.app")
        #expect(OrphanDetector.bundleID(forEntry: "com.vendor.app.binarycookies")
                == "com.vendor.app")
        #expect(OrphanDetector.bundleID(forEntry: "com.vendor.app.plist.binarycookies")
                == "com.vendor.app")
        #expect(OrphanDetector.bundleID(forEntry: "com.vendor.app.sfl4")
                == "com.vendor.app")
    }

    @Test("Non-bundle names yield nothing")
    func nonBundleNames() {
        for name in ["Cache", "logs", "Caches", "12345",
                     "MobileMeAccounts", "ByHost", "globalPreferences"] {
            #expect(OrphanDetector.bundleID(forEntry: name) == nil,
                    "\(name) must not be read as a bundle ID")
        }
    }

    @Test("Deep identifiers are rejected, real vendor prefixes are not")
    func identifierShape() {
        // A five-label path is a nested framework, not a removable app.
        #expect(OrphanDetector.bundleID(forEntry: "com.apple.private.Foo.Bar") == nil)
        // Four labels is a real shape and must survive extraction.
        #expect(OrphanDetector.bundleID(forEntry: "com.blackmagic-design.DaVinciResolve")
                == "com.blackmagic-design.DaVinciResolve")
// Four-label vendor IDs must survive extraction. `ai.elementlabs.lmstudio`
        // is the hard case: its last label is also a real extension name, so a
        // naive "peel the extension" pass turns it into `ai.elementlabs`.
        for id in ["com.wondershare.filmoramac", "ai.elementlabs.lmstudio",
                   "pro.betterdisplay.BetterDisplay", "com.blackmagic-design.DaVinciResolve"] {
            #expect(OrphanDetector.bundleID(forEntry: id) == id,
                    "\\(id) must be recognised as a bundle ID")
        }
        // And the same IDs must survive the full suffix-peeling pass.
        #expect(OrphanDetector.bundleID(forEntry: "ai.elementlabs.lmstudio.plist")
                == "ai.elementlabs.lmstudio")
        #expect(OrphanDetector.bundleID(forEntry: "ai.elementlabs.lmstudio.binarycookies")
                == "ai.elementlabs.lmstudio")
    }

    @Test("An Apple subsystem is excluded by policy, not by shape")
    func appleSubsystems() {
        // `com.apple.AddressBookSourceSync` is three labels and parses as a
        // bundle ID, so the Apple-prefix rule in isCandidate is what keeps it
        // out. Extraction alone cannot decide this.
        #expect(OrphanDetector.bundleID(forEntry: "com.apple.AddressBookSourceSync")
                == "com.apple.AddressBookSourceSync")
        #expect(!OrphanDetector.isCandidate("com.apple.AddressBookSourceSync"))
    }

    @Test("Apple and shared-data identifiers are never orphans")
    func protectedIdentifiers() {
        // Docker's container holds the user's VM images. An earlier build
        // reported 19 GB of it as leftover.
        for id in ["com.docker.docker", "com.docker", "com.apple.finder",
                   "com.apple.Safari", "com.utmapp.UTM", "com.vmware.fusion"] {
            #expect(!OrphanDetector.isCandidate(id), "\(id) must never be an orphan")
        }
        // Vendor infrastructure belongs to whichever app is installed.
        for id in ["org.sparkle-project.DownloaderService",
                   "com.microsoft.autoupdate.fba",
                   "com.google.keystone.agent"] {
            #expect(!OrphanDetector.isCandidate(id), "\(id) is shared infrastructure")
        }
        // A genuine removed vendor stays eligible.
        #expect(OrphanDetector.isCandidate("com.wondershare.filmoramac"))
    }

    @Test("Credential stores are never orphans")
    func credentialStores() {
        for id in ["com.1password.1password", "com.bitwarden.desktop",
                   "com.apple.Safari"] {
            #expect(!OrphanDetector.isCandidate(id))
        }
    }

    @Test("Short first labels are not vendor identifiers")
    func shortVendorLabels() {
        // `ai.*` and `io.*` are real TLD-backed prefixes and stay eligible;
        // `a.b` is not a vendor.
        #expect(OrphanDetector.isCandidate("ai.elementlabs.lmstudio"))
        #expect(OrphanDetector.isCandidate("io.example.app"))
        #expect(!OrphanDetector.isCandidate("a.b"))
    }

    @Test("Preferences and app data need review; caches and cookies do not")
    func reviewClassification() {
        func trace(_ kind: OrphanDetector.Leftover.Kind) -> OrphanDetector.Leftover {
            OrphanDetector.Leftover(id: "x", bundleID: "com.vendor.app",
                                    path: "/tmp/x", bytes: 1, ageDays: 1,
                                    kind: kind, location: .caches)
        }
        #expect(trace(.preferences).needsReview)
        #expect(trace(.applicationSupport).needsReview)
        #expect(trace(.container).needsReview)
        #expect(!trace(.cache).needsReview)
        #expect(!trace(.log).needsReview)
        #expect(!trace(.httpStorage).needsReview)
        #expect(!trace(.webkit).needsReview)
    }

    @Test("Traces for a bundle are grouped under that bundle")
    func grouping() {
        let traces = OrphanDetector.traces(forBundleID: "com.wondershare.filmoramac")
        // Either nothing exists on the test machine, or every trace belongs to
        // the requested bundle. A mixed result would mean wrong grouping.
        for trace in traces {
            #expect(trace.bundleID == "com.wondershare.filmoramac",
                    "\(trace.path) was grouped under the wrong app")
        }
    }

    @Test("A group container proves its app is installed")
    func groupContainerProvesPresence() {
        // Regression: these containers belong to apps that are installed. They
        // were reported as orphans because the container name was compared
        // literally against installed bundle IDs instead of being resolved to
        // the owning app.
        let installed: Set<String> = ["net.whatsapp.WhatsApp", "com.raycast.macos"]
        for name in ["group.net.whatsapp.WhatsApp.shared",
                     "group.net.whatsapp.WhatsApp.private",
                     "group.net.whatsapp.family",
                     "group.net.whatsapp.WhatsAppSMB.shared",
                     "SY64MV22J9.com.raycast.macos.shared"] {
            let bundleID = OrphanDetector.extractedBundleID(from: name) ?? name
            #expect(
                OrphanDetector.presenceProves(for: name,
                                              bundleID: bundleID,
                                              installedIDs: installed),
                "\(name) was reported as an orphan although its app is installed")
        }
    }

    @Test("A genuinely removed app still proves absent")
    func removedAppStillProvesAbsent() {
        let installed: Set<String> = ["com.apple.finder"]
        for name in ["com.somevendor.removedapp.binarycookies",
                     "com.somevendor.removedapp.plist"] {
            let bundleID = OrphanDetector.extractedBundleID(from: name) ?? name
            #expect(
                !OrphanDetector.presenceProves(for: name,
                                               bundleID: bundleID,
                                               installedIDs: installed),
                "\(name) should still be reportable")
        }
    }

    @Test("Generic filenames are never app identifiers")
    func genericFilenamesRejected() {
        // `default.store` is a SQLite file owned by some app. It is two
        // reverse-DNS-shaped labels, so shape alone is not enough to keep it.
        for name in ["default.store", "default.store-wal", "com.raycast.shared",
                     "cache", "temp"] {
            #expect(OrphanDetector.extractedBundleID(from: name) == nil,
                    "\(name) was mistaken for an app identifier")
        }
    }

    @Test("Updaters and suite identifiers are never orphans")
    func infrastructureNeverOrphan() {
        // These belong to installed apps even though no installed bundle carries
        // their own identifier, so an absence check cannot see the owner.
        for id in ["com.microsoft.EdgeUpdater.wake",
                   "com.microsoft.office",
                   "com.microsoft.autoupdate2",
                   "org.sparkle-project.GlobalAutoUpdater"] {
            #expect(!OrphanDetector.isCandidate(id),
                    "\(id) would be offered as a leftover")
        }
    }

    @Test("Sandboxes are the only locations that need Full Disk Access")
    func sandboxKinds() {
        #expect(OrphanDetector.Leftover.Kind.container.isSandbox)
        #expect(OrphanDetector.Leftover.Kind.groupContainer.isSandbox)
        // These read fine without the grant, so skipping them would hide real
        // leftovers behind a permission the user may never want to give.
        for kind: OrphanDetector.Leftover.Kind in [.cache, .log, .preferences,
                                                   .webkit, .httpStorage,
                                                   .applicationSupport, .savedState,
                                                   .launchAgent, .appScript] {
            #expect(!kind.isSandbox, "\(kind) should still be scanned")
        }
    }

    @Test("Apple group containers and shared SDKs are never orphans")
    func appleAndSDKsNeverOrphan() {
        // Shortcuts and Workflow ship with macOS, so they can never be leftovers.
        // `io.sentry` is a crash-reporting library embedded in many unrelated
        // apps; its folder outliving any one of them proves nothing.
        for id in ["group.is.workflow.shortcuts", "group.is.workflow.my.app",
                   "group.tvappservices.container", "systemgroup.is.workflow",
                   "io.sentry", "com.crashlytics"] {
            #expect(!OrphanDetector.isCandidate(id),
                    "\(id) would be offered as a leftover")
        }
    }

    @Test("Application Scripts is never scanned")
    func applicationScriptsNotScanned() {
        // Deleting an AppleScript terminology definition breaks an installed
        // app's scripting, and macOS will not even let the folder be read
        // without Full Disk Access, so every entry measured 0 bytes.
        #expect(!OrphanDetector.locations.contains { $0.location == .appScripts },
                "Application Scripts must not be a cleanup target")
    }

    @Test("A removal plan collects traces without any of them being removable by accident")
    func removalPlan() {
        let plan = AppRemovalPlan(app: InstalledApps.App(
            id: "com.vendor.app", name: "Vendor", path: "/Applications/Vendor.app",
            version: "1.0", sizeBytes: 100, isSystem: false, isRunning: false,
            signer: nil), traces: [])
        #expect(plan.traces.isEmpty)
        #expect(plan.bytes == 0)
        #expect(plan.autoSelected.isEmpty)
    }
}

@Suite("Installed app inventory")
struct InstalledAppsTests {

    @Test("Bundle discovery finds real apps and does not walk inside them")
    func bundleDiscovery() {
        let found = InstalledApps.discoverBundles(under: "/Applications")
        #expect(!found.isEmpty, "this machine has apps in /Applications")
        for url in found.prefix(20) {
            #expect(url.pathExtension == "app")
        }
    }

    @Test("Inventory returns apps with a path that exists")
    func inventory() {
        let apps = InstalledApps.all()
        #expect(!apps.isEmpty)
        for app in apps.prefix(15) {
            #expect(FileManager.default.fileExists(atPath: app.path),
                    "\(app.name) points at a path that does not exist")
            #expect(app.sizeBytes >= 0)
        }
    }

    @Test("Bundle ID lookup resolves to a real app bundle")
    func lookupConsistency() {
        for app in InstalledApps.all().prefix(8) {
            let url = InstalledApps.appURL(forBundleID: app.id)
            #expect(url != nil, "no URL resolved for installed \(app.id)")
            // The folder name and the display name legitimately differ (Finder
            // renames bundles), so only the path is asserted.
            #expect(url?.pathExtension == "app",
                    "lookup for \(app.id) returned \(url?.path ?? "nil")")
        }
    }

    @Test("Every bundle ID in the search paths has at least one app")
    func bundleIDSweep() {
        let ids = InstalledApps.bundleIDsInSearchPaths
        let known = Set(InstalledApps.all().map(\.id))
        // The sweep is a superset, used to keep traces of apps the inventory
        // could not size. A small difference is expected; a reversed one is not.
        #expect(known.subtracting(ids).isEmpty,
                "the ID sweep missed bundles the inventory found")
    }
}