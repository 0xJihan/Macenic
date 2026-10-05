import Foundation

struct StorageCategory: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let bytes: UInt64
    let icon: String
}

struct StorageInfo: Sendable {
    var totalBytes: UInt64 = 0
    var usedBytes: UInt64 = 0
    var freeBytes: UInt64 = 0
    var purgeableBytes: UInt64 = 0
    var categories: [StorageCategory] = []
    var isCalculatingCategories: Bool = false
    var lastCalculated: Date?

    var usagePercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }
}
