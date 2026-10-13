import Foundation
import Observation

@MainActor
@Observable
final class ScanEngine {
    var isScanning = false
    var isCleaning = false
    var progressLabel = L10n.string("smartcare.idle")
    var completedCategories = 0
    var totalCategories = ScannerRegistry.all.count
    var results: [CategoryResult] = []
    var lastCleanResult: CleanResult?
    var errorMessage: String?

    /// Owned by the engine (App lifetime), not by a SwiftUI view Task — survives section changes.
    private var workTask: Task<Void, Never>?

    var isBusy: Bool { isScanning || isCleaning }

    /// 0…1 while scanning categories; −1 while cleaning (indeterminate ring).
    var scanProgress: Double {
        if isCleaning { return -1 }
        guard isScanning, totalCategories > 0 else { return 0 }
        return Double(completedCategories) / Double(totalCategories)
    }

    var reclaimableBytes: Int64 {
        results
            .filter { $0.category.isCleanable }
            .flatMap(\.items)
            .filter(\.isSelected)
            .reduce(0) { $0 + $1.byteCount }
    }

    var scannedBytes: Int64 {
        results.reduce(0) { $0 + $1.totalBytes }
    }

    /// Starts Smart Care without awaiting — safe to call from any UI; keeps running across navigation.
    func runSmartCare() {
        guard !isBusy else { return }
        workTask?.cancel()
        workTask = Task { await self.performSmartCare() }
    }

    func cleanSelected() {
        guard !isBusy else { return }
        workTask?.cancel()
        workTask = Task { await self.performCleanSelected() }
    }

    func stop() {
        workTask?.cancel()
        workTask = nil
        if isScanning || isCleaning {
            progressLabel = L10n.string("smartcare.stopped")
        }
        isScanning = false
        isCleaning = false
    }

    private func performSmartCare() async {
        isScanning = true
        isCleaning = false
        lastCleanResult = nil
        errorMessage = nil
        results = []
        completedCategories = 0
        progressLabel = L10n.string("smartcare.starting")

        let scanners = ScannerRegistry.all
        totalCategories = scanners.count

        await withTaskGroup(of: CategoryResult?.self) { group in
            for scanner in scanners {
                group.addTask {
                    if Task.isCancelled { return nil }
                    let items = await scanner.scan()
                    if Task.isCancelled { return nil }
                    return CategoryResult(category: scanner.category, items: items)
                }
            }

            for await result in group {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                guard let result else { continue }
                results.append(result)
                results.sort { $0.totalBytes > $1.totalBytes }
                completedCategories += 1
                progressLabel = L10n.format("smartcare.scanned_category", result.category.title)
            }
        }

        if Task.isCancelled {
            progressLabel = L10n.string("smartcare.stopped")
        } else {
            progressLabel = L10n.string("smartcare.complete")
        }
        isScanning = false
    }

    private func performCleanSelected() async {
        isCleaning = true
        progressLabel = L10n.string("smartcare.moving")
        let selected = results.flatMap(\.items).filter { $0.isSelected && $0.category.isCleanable }
        let result = await Cleaner.moveToTrash(selected, isCancelled: { Task.isCancelled })
        if Task.isCancelled {
            progressLabel = L10n.string("smartcare.stopped")
            isCleaning = false
            return
        }
        lastCleanResult = result
        if !result.failed.isEmpty {
            errorMessage = L10n.format("smartcare.failed_count", Int64(result.failed.count))
        }
        progressLabel = L10n.format("smartcare.freed", ByteFormat.string(result.freedBytes))
        isCleaning = false
        await performSmartCare()
    }

    func toggleItem(_ item: ScanItem) {
        guard let cIdx = results.firstIndex(where: { $0.category == item.category }),
              let iIdx = results[cIdx].items.firstIndex(where: { $0.id == item.id })
        else { return }
        results[cIdx].items[iIdx].isSelected.toggle()
    }

    func selectAll(in category: ScanCategory, selected: Bool) {
        guard let idx = results.firstIndex(where: { $0.category == category }) else { return }
        guard category.isCleanable else { return }
        for i in results[idx].items.indices {
            results[idx].items[i].isSelected = selected
        }
    }
}
