import Foundation
import Network
import CoreWLAN
import Darwin

@Observable
final class NetworkMonitorService {
    var info = NetworkInfo()

    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private let monitorQueue = DispatchQueue(label: "com.rahadul.Macenic.networkMonitor", qos: .utility)
    @ObservationIgnored private var latencyTimer: Timer?
    @ObservationIgnored private var isMonitoringViewActive = false

    func start() {
        guard pathMonitor == nil else { return }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: monitorQueue)
        pathMonitor = monitor
    }

    func stop() {
        pathMonitor?.cancel()
        pathMonitor = nil
        stopLatencyPolling()
    }

    func onScreenAppear() {
        isMonitoringViewActive = true
        measureLatency()
        startLatencyPolling()
    }

    func onScreenDisappear() {
        isMonitoringViewActive = false
        stopLatencyPolling()
    }

    private func startLatencyPolling() {
        guard latencyTimer == nil else { return }
        latencyTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.measureLatency()
        }
    }

    private func stopLatencyPolling() {
        latencyTimer?.invalidate()
        latencyTimer = nil
    }

    private func handlePathUpdate(_ path: NWPath) {
        let isConnected = (path.status == .satisfied)

        var primaryName = "None"
        var primaryType: NetworkInterfaceType = .other

        if let iface = path.availableInterfaces.first {
            primaryName = iface.name
            switch iface.type {
            case .wifi:
                primaryType = .wifi
            case .wiredEthernet:
                primaryType = .ethernet
            case .cellular:
                primaryType = .cellular
            default:
                primaryType = .other
            }
        }

        var ssid: String? = nil
        if primaryType == .wifi {
            ssid = CWWiFiClient.shared().interface()?.ssid()
        }

        let localIP = findLocalIPv4(for: primaryName)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.info.isConnected = isConnected
            self.info.interfaceName = primaryName
            self.info.interfaceType = primaryType
            self.info.ssid = ssid
            self.info.localIP = localIP
        }
    }

    private func findLocalIPv4(for interfaceName: String) -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = ptr {
            let name = String(cString: addr.pointee.ifa_name)
            if name == interfaceName && addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr.pointee.ifa_addr,
                    socklen_t(addr.pointee.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                ) == 0 {
                    return String(cString: hostname)
                }
            }
            ptr = addr.pointee.ifa_next
        }

        return nil
    }

    func measureLatency() {
        guard info.isConnected else {
            DispatchQueue.main.async { [weak self] in
                self?.info.latencyMs = nil
                self?.info.isMeasuringLatency = false
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.info.isMeasuringLatency = true
        }

        let host = NWEndpoint.Host("1.1.1.1")
        let port = NWEndpoint.Port(integerLiteral: 53)
        let connection = NWConnection(host: host, port: port, using: .tcp)
        let startTime = CFAbsoluteTimeGetCurrent()

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .ready:
                let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
                connection?.cancel()
                DispatchQueue.main.async {
                    self?.info.latencyMs = durationMs
                    self?.info.isMeasuringLatency = false
                }
            case .failed, .cancelled:
                connection?.cancel()
                DispatchQueue.main.async {
                    self?.info.isMeasuringLatency = false
                }
            default:
                break
            }
        }

        connection.start(queue: monitorQueue)

        // Cancel after timeout if not ready
        monitorQueue.asyncAfter(deadline: .now() + 3.0) { [weak connection, weak self] in
            if connection?.state != .ready {
                connection?.cancel()
                DispatchQueue.main.async {
                    self?.info.isMeasuringLatency = false
                }
            }
        }
    }
}
