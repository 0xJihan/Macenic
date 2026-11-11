import Foundation
import IOKit
import IOKit.ps

@Observable
final class BatteryHealthService {
    var info = BatteryHealthInfo()

    @ObservationIgnored private var wasCharging = false
    @ObservationIgnored private var timer: Timer?

    func start() {
        info.lastChargingTime = UserDefaults.standard.object(forKey: "lastChargingTime") as? Date
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.update()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func update() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any]
        else {
            info.hasBattery = false
            info.powerSource = "AC Power (Desktop Mac)"
            return
        }

        info.hasBattery = true
        info.level = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        info.isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        info.isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
        info.powerSource = info.isPluggedIn ? "Power Adapter (AC)" : "Battery Power"

        let timeEstimate = IOPSGetTimeRemainingEstimate()
        info.timeRemainingMinutes = timeEstimate >= 0 ? Int(timeEstimate / 60) : -1

        // Hardware details from AppleSmartBattery
        updateHardwareDetails()

        // Track charging completion
        if wasCharging && !info.isCharging && info.isPluggedIn {
            info.lastChargingTime = Date()
            UserDefaults.standard.set(info.lastChargingTime, forKey: "lastChargingTime")
        }
        wasCharging = info.isCharging
    }

    private func updateHardwareDetails() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return
        }

        info.cycleCount = dict["CycleCount"] as? Int ?? 0
        info.designCycleCount = (dict["DesignCycleCount9C"] as? Int) ?? (dict["DesignCycleCount"] as? Int)

        // Voltage and Amperage
        let voltage = dict["Voltage"] as? Int ?? 0 // mV
        let amperage = dict["Amperage"] as? Int ?? 0 // mA
        if voltage > 0 && amperage != 0 {
            info.wattage = Double(voltage) * Double(abs(amperage)) / 1_000_000.0
        } else {
            info.wattage = nil
        }

        // Capacity and Health from BatteryData or root
        if let batteryData = dict["BatteryData"] as? [String: Any] {
            let designCap = (batteryData["DesignCapacity"] as? Int) ?? 0
            let nominalCap = (batteryData["NominalChargeCapacity"] as? Int) ??
                             (batteryData["FullChargeCapacity"] as? Int) ?? 0
            let currentCap = (batteryData["CurrentCapacity"] as? Int) ??
                             (batteryData["RemainingCapacity"] as? Int) ?? 0

            if designCap > 0 {
                info.designCapacityMah = designCap
            }
            if nominalCap > 0 {
                info.fullChargeCapacityMah = nominalCap
            }
            if currentCap > 0 {
                info.currentCapacityMah = currentCap
            }

            if designCap > 0 && nominalCap > 0 {
                let health = Int(round(Double(nominalCap) / Double(designCap) * 100.0))
                info.maxCapacityPercent = min(max(health, 1), 100)
            }
        } else {
            // Intel fallback
            let maxCap = dict["MaxCapacity"] as? Int ?? 0
            let designCap = dict["DesignCapacity"] as? Int ?? 0
            let currentCap = dict["CurrentCapacity"] as? Int ?? 0

            if maxCap > 0 { info.fullChargeCapacityMah = maxCap }
            if designCap > 0 { info.designCapacityMah = designCap }
            if currentCap > 0 { info.currentCapacityMah = currentCap }

            if designCap > 0 && maxCap > 0 {
                let health = Int(round(Double(maxCap) / Double(designCap) * 100.0))
                info.maxCapacityPercent = min(max(health, 1), 100)
            }
        }

        // Condition evaluation
        if let failureStatus = dict["PermanentFailureStatus"] as? Int, failureStatus != 0 {
            info.condition = "Service Battery"
        } else if let health = info.maxCapacityPercent, health < 80 {
            info.condition = "Service Recommended"
        } else {
            info.condition = "Normal"
        }
    }
}
