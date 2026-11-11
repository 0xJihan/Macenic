import Foundation

enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB"]
    private static let speedUnits = ["B/s", "KB/s", "MB/s", "GB/s"]

    static func format(_ bytes: UInt64) -> String {
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0
            ? String(format: "%.0f %@", value, units[unitIndex])
            : String(format: "%.1f %@", value, units[unitIndex])
    }

    static func formatSpeed(_ bytesPerSecond: UInt64) -> String {
        var value = Double(bytesPerSecond)
        var unitIndex = 0
        while value >= 1024 && unitIndex < speedUnits.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0
            ? String(format: "%.0f %@", value, speedUnits[unitIndex])
            : String(format: "%.1f %@", value, speedUnits[unitIndex])
    }
}
