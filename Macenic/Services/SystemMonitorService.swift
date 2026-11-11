import Foundation
import Darwin
import IOKit
import IOKit.ps
import Metal

@Observable
final class SystemMonitorService {
    var cpuUsage: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var diskUsed: UInt64 = 0
    var diskTotal: UInt64 = 0
    var networkSpeedIn: UInt64 = 0
    var networkSpeedOut: UInt64 = 0
    var batteryLevel: Int = -1
    var batteryIsCharging: Bool = false
    var batteryIsPluggedIn: Bool = false
    var batteryTimeRemaining: Int = -1
    var batteryCycleCount: Int = 0
    var batteryHealth: Int = 100
    var lastChargingTime: Date?
    var gpuName: String = "Unknown"
    var gpuUtilization: Double = 0
    var gpuMemoryUsedBytes: UInt64 = 0
    var gpuMemoryTotalBytes: UInt64 = 0

    var hasBattery: Bool { batteryLevel >= 0 }

    var memoryUsagePercent: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryUsed) / Double(memoryTotal) * 100
    }

    var diskUsagePercent: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskUsed) / Double(diskTotal) * 100
    }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var previousCPUTicks: [(user: Int64, system: Int64, idle: Int64, nice: Int64)] = []
    @ObservationIgnored private var previousBytesIn: UInt64 = 0
    @ObservationIgnored private var previousBytesOut: UInt64 = 0
    @ObservationIgnored private var wasCharging = false

    func start() {
        lastChargingTime = UserDefaults.standard.object(forKey: "lastChargingTime") as? Date
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        updateCPU()
        updateMemory()
        updateDisk()
        updateNetwork()
        updateBattery()
        updateGPU()
    }

    private func updateCPU() {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var currentTicks: [(user: Int64, system: Int64, idle: Int64, nice: Int64)] = []

        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            currentTicks.append((
                user: Int64(info[offset + Int(CPU_STATE_USER)]),
                system: Int64(info[offset + Int(CPU_STATE_SYSTEM)]),
                idle: Int64(info[offset + Int(CPU_STATE_IDLE)]),
                nice: Int64(info[offset + Int(CPU_STATE_NICE)])
            ))
        }

        if previousCPUTicks.count == currentTicks.count {
            var totalUsed: Int64 = 0
            var totalAll: Int64 = 0

            for i in 0..<currentTicks.count {
                let userD = currentTicks[i].user - previousCPUTicks[i].user
                let systemD = currentTicks[i].system - previousCPUTicks[i].system
                let idleD = currentTicks[i].idle - previousCPUTicks[i].idle
                let niceD = currentTicks[i].nice - previousCPUTicks[i].nice

                totalUsed += userD + systemD + niceD
                totalAll += userD + systemD + idleD + niceD
            }

            cpuUsage = totalAll > 0 ? Double(totalUsed) / Double(totalAll) * 100 : 0
        }

        previousCPUTicks = currentTicks

        let size = vm_size_t(Int(numCPUInfo) * MemoryLayout<Int32>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
    }

    private func updateMemory() {
        memoryTotal = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return }

        let pageSize = UInt64(vm_kernel_page_size)
        memoryUsed = UInt64(stats.active_count) * pageSize
            + UInt64(stats.wire_count) * pageSize
            + UInt64(stats.compressor_page_count) * pageSize
    }

    private func updateDisk() {
        let url = URL(fileURLWithPath: "/")
        guard let values = try? url.resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        ) else { return }

        let total = values.volumeTotalCapacity ?? 0
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        diskTotal = UInt64(total)
        diskUsed = UInt64(max(0, Int64(total) - available))
    }

    private func updateNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr {
            if addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
               let data = addr.pointee.ifa_data {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(ifData.ifi_ibytes)
                totalOut += UInt64(ifData.ifi_obytes)
            }
            ptr = addr.pointee.ifa_next
        }

        if previousBytesIn > 0 && totalIn >= previousBytesIn {
            networkSpeedIn = (totalIn - previousBytesIn) / 2
            networkSpeedOut = (totalOut >= previousBytesOut)
                ? (totalOut - previousBytesOut) / 2 : 0
        }

        previousBytesIn = totalIn
        previousBytesOut = totalOut
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            batteryLevel = -1
            return
        }

        batteryLevel = info[kIOPSCurrentCapacityKey] as? Int ?? 0
        batteryIsCharging = info[kIOPSIsChargingKey] as? Bool ?? false
        batteryIsPluggedIn = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        batteryHealth = info[kIOPSMaxCapacityKey] as? Int ?? 100

        let timeRemaining = IOPSGetTimeRemainingEstimate()
        batteryTimeRemaining = timeRemaining >= 0 ? Int(timeRemaining / 60) : -1

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
           let dict = props?.takeRetainedValue() as? [String: Any] {
            batteryCycleCount = dict["CycleCount"] as? Int ?? 0
        }

        if wasCharging && !batteryIsCharging {
            lastChargingTime = Date()
            UserDefaults.standard.set(lastChargingTime, forKey: "lastChargingTime")
        }
        wasCharging = batteryIsCharging
    }

    private func updateGPU() {
        if let device = MTLCreateSystemDefaultDevice() {
            gpuName = device.name
            if device.recommendedMaxWorkingSetSize > 0 {
                gpuMemoryTotalBytes = device.recommendedMaxWorkingSetSize
            }
        }

        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            if let stats = IORegistryEntryCreateCFProperty(
                service,
                "PerformanceStatistics" as CFString,
                kCFAllocatorDefault,
                0
            )?.takeRetainedValue() as? [String: Any] {
                if let utilization = extractGPUUtilization(from: stats) {
                    gpuUtilization = min(max(utilization, 0), 100)
                }
                if let used = extractGPUMemoryUsed(from: stats) {
                    gpuMemoryUsedBytes = used
                }
            }

            service = IOIteratorNext(iterator)
        }
    }

    private func extractGPUUtilization(from stats: [String: Any]) -> Double? {
        let keys = [
            "Device Utilization %",
            "GPU Core Utilization",
            "GPU Busy",
            "GPU Activity(%)",
            "GPU Usage %"
        ]
        for key in keys {
            if let value = stats[key] as? NSNumber {
                let raw = value.doubleValue
                if raw > 10000 { return raw / 1000 }
                if raw > 1000 { return raw / 100 }
                if raw > 100 { return raw / 10 }
                return raw
            }
        }
        return nil
    }

    private func extractGPUMemoryUsed(from stats: [String: Any]) -> UInt64? {
        let keys = [
            "vramUsedBytes",
            "VRAM In Use Bytes",
            "In use system memory",
            "Alloc system memory"
        ]
        for key in keys {
            if let value = stats[key] as? NSNumber {
                return value.uint64Value
            }
        }
        return nil
    }
}
