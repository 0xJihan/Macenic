import Foundation

struct BatteryHealthInfo {
    var hasBattery: Bool = false
    var level: Int = -1
    var isCharging: Bool = false
    var isPluggedIn: Bool = false
    var powerSource: String = "AC Power"
    var timeRemainingMinutes: Int = -1
    var cycleCount: Int = 0
    var designCycleCount: Int?
    var maxCapacityPercent: Int?
    var currentCapacityMah: Int?
    var fullChargeCapacityMah: Int?
    var designCapacityMah: Int?
    var condition: String = "Normal"
    var wattage: Double?
    var lastChargingTime: Date?
}
