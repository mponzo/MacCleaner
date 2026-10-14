import Foundation
import Observation

@MainActor
@Observable
final class UninstallerEngine {
    var isLoading = false
    var isUninstalling = false
    var apps: [InstalledApp] = []
    var orphanLeftovers: [AppLeftover] = []
    var selectedAppID: InstalledApp.ID?
    var query = ""
    var progressLabel = L10n.string("smartcare.idle")
    var lastResult: CleanResult?
    var errorMessage: String?

    var filteredApps: [InstalledApp] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = apps.filter { !$0.isSystemApp }
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(q)
        }
    }

    var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedAppID }
    }

    var orphanBytes: Int64 {
        orphanLeftovers.filter(\.isSelected).reduce(0) { $0 + $1.byteCount }
    }

    func refresh(clearFeedback: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        progressLabel = L10n.string("apps.listing")
        if clearFeedback {
            errorMessage = nil
            lastResult = nil
        }

        let listed = await ApplicationsCatalog.listInstalledApps()
        progressLabel = L10n.string("apps.scanning_leftovers")
        apps = await ApplicationsCatalog.enrichWithLeftovers(listed)

        let ids = Set(apps.map(\.bundleIdentifier))
        progressLabel = L10n.string("apps.finding_orphans")
        orphanLeftovers = await LeftoverDiscovery.orphanLeftovers(installedBundleIDs: ids)

        if let selectedAppID, apps.contains(where: { $0.id == selectedAppID }) {
            // keep current selection
        } else {
            self.selectedAppID = filteredApps.first?.id
        }
        if clearFeedback {
            progressLabel = L10n.format("apps.summary", Int64(filteredApps.count), ByteFormat.string(orphanBytes))
        }
        isLoading = false
    }

    func toggleLeftover(appID: InstalledApp.ID, leftoverID: AppLeftover.ID) {
        guard let aIdx = apps.firstIndex(where: { $0.id == appID }),
              let lIdx = apps[aIdx].leftovers.firstIndex(where: { $0.id == leftoverID })
        else { return }
        apps[aIdx].leftovers[lIdx].isSelected.toggle()
    }

    func toggleIncludeBundle(appID: InstalledApp.ID) {
        guard let idx = apps.firstIndex(where: { $0.id == appID }) else { return }
        guard !apps[idx].isProtected else { return }
        apps[idx].includeAppBundle.toggle()
    }

    func toggleOrphan(_ leftoverID: AppLeftover.ID) {
        guard let idx = orphanLeftovers.firstIndex(where: { $0.id == leftoverID }) else { return }
        orphanLeftovers[idx].isSelected.toggle()
    }

    func uninstallSelectedApp() async {
        guard let app = selectedApp, !app.isProtected, !isUninstalling else { return }
        isUninstalling = true
        errorMessage = nil
        progressLabel = L10n.format("apps.uninstalling", app.name)

        if app.includeAppBundle {
            await AppUninstall.quitIfRunning(bundleURL: app.bundleURL, bundleID: app.bundleIdentifier)
        }

        var urls: [URL] = []
        if app.includeAppBundle {
            urls.append(app.bundleURL)
        }
        urls.append(contentsOf: app.leftovers.filter(\.isSelected).map(\.url))

        guard !urls.isEmpty else {
            isUninstalling = false
            errorMessage = L10n.format("apps.failed_paths", Int64(0))
            return
        }

        // PureMac path: one AppFileTrasher pass over app + leftovers (trash → Finder → admin).
        let report = await AppUninstall.trashLikePureMac(urls)
        let result = report.result
        isUninstalling = false
        await refresh(clearFeedback: false)

        lastResult = result
        if result.failed.isEmpty {
            errorMessage = nil
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        } else {
            var message = L10n.format("apps.failed_paths", Int64(result.failed.count))
            if report.needsFullDiskAccess {
                message = L10n.format("apps.needs_fda", app.name, Int64(result.failed.count))
            } else if let detail = result.failed.first?.1, !detail.isEmpty {
                message += " — \(detail)"
            }
            if report.attemptedAdmin, !report.needsFullDiskAccess {
                message += " " + L10n.string("apps.admin_hint")
            }
            errorMessage = message
            progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        }
    }

    /// Focus Applications after Finder Service “Uninstall with MacCleaner”.
    func prepareForServiceUninstall(bundleURL: URL) async {
        let target = bundleURL.standardizedFileURL
        await refresh(clearFeedback: true)
        if let match = apps.first(where: {
            $0.bundleURL.standardizedFileURL == target
                || $0.bundleURL.standardizedFileURL.path == target.path
        }) {
            selectedAppID = match.id
            progressLabel = L10n.format("service.uninstall.ready", match.name)
            return
        }

        // App may live outside catalog roots — synthesize a row for review.
        let name = Bundle(url: target)?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle(url: target)?.infoDictionary?["CFBundleName"] as? String
            ?? target.deletingPathExtension().lastPathComponent
        let bundleID = Bundle(url: target)?.bundleIdentifier
            ?? (Bundle(url: target)?.infoDictionary?["CFBundleIdentifier"] as? String)
            ?? "unknown.\(target.lastPathComponent)"
        let version = Bundle(url: target)?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let bytes = DiskSizer.allocatedBytes(at: target)
        let synthetic = InstalledApp(
            name: name,
            bundleIdentifier: bundleID,
            version: version,
            bundleURL: target,
            byteCount: bytes,
            isSystemApp: target.path.hasPrefix("/System"),
            isProtected: target.path.hasPrefix("/System"),
            leftovers: [],
            includeAppBundle: true
        )
        if !apps.contains(where: { $0.id == synthetic.id }) {
            apps.insert(synthetic, at: 0)
        }
        selectedAppID = synthetic.id
        progressLabel = L10n.format("service.uninstall.ready", name)
    }

    func cleanSelectedOrphans() async {
        guard !isUninstalling else { return }
        let selected = orphanLeftovers.filter(\.isSelected)
        guard !selected.isEmpty else { return }
        isUninstalling = true
        errorMessage = nil
        progressLabel = L10n.string("apps.cleaning_orphans")

        let report = await AppUninstall.trashLikePureMac(selected.map(\.url))
        let result = report.result
        isUninstalling = false
        await refresh(clearFeedback: false)

        lastResult = result
        if result.failed.isEmpty {
            errorMessage = nil
        } else if report.needsFullDiskAccess {
            errorMessage = L10n.format("apps.needs_fda_generic", Int64(result.failed.count))
        } else {
            var message = L10n.format("apps.failed_paths", Int64(result.failed.count))
            if let detail = result.failed.first?.1, !detail.isEmpty {
                message += " \(detail)"
            }
            errorMessage = message
        }
        progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
    }
}
