import AppKit

struct ProcessItem: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let cpuUsage: Double
    let memoryBytes: UInt64
    let isApp: Bool
    let appRef: NSRunningApplication?
    let isProtected: Bool

    static func == (lhs: ProcessItem, rhs: ProcessItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.cpuUsage == rhs.cpuUsage &&
        lhs.memoryBytes == rhs.memoryBytes &&
        lhs.name == rhs.name
    }
}

enum ProcessSortOption: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"
    case name = "Name"
    case pid = "PID"

    var id: String { rawValue }
}

enum ProcessFilterOption: String, CaseIterable, Identifiable {
    case appsOnly = "Apps Only"
    case all = "All Processes"

    var id: String { rawValue }
}
