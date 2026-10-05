import Foundation
import AppKit

@Observable
final class StorageMonitorService {
    var info = StorageInfo()

    @ObservationIgnored private var timer: Timer?

    func start() {
        updateVolumeMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateVolumeMetrics()
        }
        calculateCategoriesIfNeeded()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func updateVolumeMetrics() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]) else { return }

        let total = UInt64(values.volumeTotalCapacity ?? 0)
        let available = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        let opportunistic = UInt64(values.volumeAvailableCapacityForOpportunisticUsage ?? 0)

        info.totalBytes = total
        info.freeBytes = available
        info.usedBytes = total > available ? (total - available) : 0
        info.purgeableBytes = opportunistic
    }

    func calculateCategoriesIfNeeded() {
        if info.categories.isEmpty || (info.lastCalculated != nil && Date().timeIntervalSince(info.lastCalculated!) > 300) {
            refreshCategories()
        }
    }

    func refreshCategories() {
        guard !info.isCalculatingCategories else { return }
        info.isCalculatingCategories = true

        let totalUsed = info.usedBytes

        Task.detached(priority: .background) { [weak self] in
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser

            let appsSize = Self.shallowDirectorySize(at: URL(fileURLWithPath: "/Applications")) +
                           Self.shallowDirectorySize(at: home.appendingPathComponent("Applications"))

            let docsSize = Self.shallowDirectorySize(at: home.appendingPathComponent("Documents"))
            let downloadsSize = Self.shallowDirectorySize(at: home.appendingPathComponent("Downloads"))

            let devURL = home.appendingPathComponent("Developer")
            let devSize = fm.fileExists(atPath: devURL.path) ? Self.shallowDirectorySize(at: devURL) : 0

            let knownSum = appsSize + docsSize + downloadsSize + devSize
            let systemRemainder = totalUsed > knownSum ? (totalUsed - knownSum) : 0

            var categories: [StorageCategory] = [
                StorageCategory(id: "apps", name: "Applications", bytes: appsSize, icon: "app.badge"),
                StorageCategory(id: "docs", name: "Documents", bytes: docsSize, icon: "doc.text"),
                StorageCategory(id: "downloads", name: "Downloads", bytes: downloadsSize, icon: "arrow.down.circle")
            ]

            if devSize > 0 {
                categories.append(StorageCategory(id: "dev", name: "Developer", bytes: devSize, icon: "hammer"))
            }

            categories.append(StorageCategory(id: "system", name: "System & Other", bytes: systemRemainder, icon: "internaldrive"))

            await MainActor.run {
                guard let self else { return }
                self.info.categories = categories
                self.info.isCalculatingCategories = false
                self.info.lastCalculated = Date()
            }
        }
    }

    private static func shallowDirectorySize(at url: URL) -> UInt64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey],
            options: [.skipsPackageDescendants, .skipsHiddenFiles]
        ) else { return 0 }

        var total: UInt64 = 0
        var count = 0

        // Limit to first 2,000 files per directory to maintain extreme speed
        for case let fileURL as URL in enumerator {
            count += 1
            if count > 2000 { break }

            if let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isDirectoryKey]),
               values.isDirectory != true {
                total += UInt64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            }
        }

        return total
    }

    func openStorageSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.Storage",
            "x-apple.systempreferences:com.apple.preference.general?Storage"
        ]

        for str in urls {
            if let url = URL(string: str), NSWorkspace.shared.open(url) {
                return
            }
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
