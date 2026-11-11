import Foundation
import Network

enum NetworkInterfaceType: String {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case cellular = "Cellular"
    case other = "Other"

    var icon: String {
        switch self {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .other: return "network"
        }
    }
}

struct NetworkInfo {
    var isConnected: Bool = false
    var interfaceName: String = "None"
    var interfaceType: NetworkInterfaceType = .other
    var ssid: String?
    var localIP: String?
    var latencyMs: Double?
    var isMeasuringLatency: Bool = false
}
