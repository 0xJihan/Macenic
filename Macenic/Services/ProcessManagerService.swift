import AppKit
import Darwin

@Observable
final class ProcessManagerService {
    var processes: [ProcessItem] = []
    var searchQuery: String = ""
    var sortOption: ProcessSortOption = .cpu
    var sortAscending: Bool = false
    var filterOption: ProcessFilterOption = .appsOnly
    var isLoading: Bool = false
    var statusMessage: String?

    var filteredProcesses: [ProcessItem] {
        var list = processes

        switch filterOption {
        case .appsOnly:
            list = list.filter { $0.isApp }
        case .all:
            break
        }

        if !searchQuery.isEmpty {
            list = list.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                String($0.id).contains(searchQuery)
            }
        }

        return list.sorted { lhs, rhs in
            let result: Bool
            switch sortOption {
            case .cpu:
                result = lhs.cpuUsage < rhs.cpuUsage
            case .memory:
                result = lhs.memoryBytes < rhs.memoryBytes
            case .name:
                result = lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .pid:
                result = lhs.id < rhs.id
            }
            return sortAscending ? result : !result
        }
    }

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var previousCPUTimes: [pid_t: (time: UInt64, timestamp: CFAbsoluteTime)] = [:]
    @ObservationIgnored private let ownPID = getpid()

    func startPolling() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let sampled = self.sampleProcesses()
            await MainActor.run {
                self.processes = sampled
            }
        }
    }

    private func sampleProcesses() -> [ProcessItem] {
        let runningApps = NSWorkspace.shared.runningApplications
        var appDict: [pid_t: NSRunningApplication] = [:]
        for app in runningApps {
            appDict[app.processIdentifier] = app
        }

        let now = CFAbsoluteTimeGetCurrent()
        var items: [ProcessItem] = []

        // If filter is appsOnly, we can sample only running apps for extreme speed
        if filterOption == .appsOnly {
            for (pid, app) in appDict {
                guard let item = sampleSingleProcess(pid: pid, appRef: app, now: now) else { continue }
                items.append(item)
            }
            return items
        }

        // Otherwise list all PIDs
        let numPids = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard numPids > 0 else { return items }

        var pids = [pid_t](repeating: 0, count: Int(numPids) / MemoryLayout<pid_t>.stride)
        let actualBytes = proc_listpids(
            UInt32(PROC_ALL_PIDS),
            0,
            &pids,
            Int32(pids.count * MemoryLayout<pid_t>.stride)
        )
        let count = Int(actualBytes) / MemoryLayout<pid_t>.stride

        for i in 0..<count {
            let pid = pids[i]
            guard pid > 0 else { continue }
            let app = appDict[pid]
            guard let item = sampleSingleProcess(pid: pid, appRef: app, now: now) else { continue }
            items.append(item)
        }

        return items
    }

    private func sampleSingleProcess(pid: pid_t, appRef: NSRunningApplication?, now: CFAbsoluteTime) -> ProcessItem? {
        var taskInfo = proc_taskinfo()
        let size = proc_pidinfo(
            pid,
            PROC_PIDTASKINFO,
            0,
            &taskInfo,
            Int32(MemoryLayout<proc_taskinfo>.size)
        )

        guard size == MemoryLayout<proc_taskinfo>.size else {
            return nil
        }

        let memory = UInt64(taskInfo.pti_resident_size)
        let totalCPUTime = UInt64(taskInfo.pti_total_user) + UInt64(taskInfo.pti_total_system)

        var cpuPercent: Double = 0.0
        if let prev = previousCPUTimes[pid] {
            let deltaSeconds = now - prev.timestamp
            if deltaSeconds > 0 && totalCPUTime >= prev.time {
                let deltaNanos = Double(totalCPUTime - prev.time)
                cpuPercent = (deltaNanos / (deltaSeconds * 1_000_000_000)) * 100.0
            }
        }
        previousCPUTimes[pid] = (totalCPUTime, now)

        let name: String
        let isApp: Bool
        let icon: NSImage?

        if let app = appRef {
            name = app.localizedName ?? "App"
            isApp = true
            icon = app.icon
        } else {
            var nameBuffer = [CChar](repeating: 0, count: 256)
            proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let procString = String(cString: nameBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            name = procString.isEmpty ? "PID \(pid)" : procString
            isApp = false
            icon = nil
        }

        let isProtected = (pid == ownPID) || (pid == 0) || (pid == 1) || (name.lowercased() == "windowserver")

        return ProcessItem(
            id: pid,
            name: name,
            icon: icon,
            cpuUsage: min(max(cpuPercent, 0), 1600), // Cap reasonable max across multi-core
            memoryBytes: memory,
            isApp: isApp,
            appRef: appRef,
            isProtected: isProtected
        )
    }

    func activate(process: ProcessItem) {
        process.appRef?.activate(options: .activateIgnoringOtherApps)
    }

    func revealInFinder(process: ProcessItem) {
        guard let url = process.appRef?.bundleURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func quit(process: ProcessItem) {
        guard !process.isProtected else {
            statusMessage = "Cannot terminate protected system process"
            return
        }

        if let app = process.appRef {
            app.terminate()
        } else {
            kill(process.id, SIGTERM)
        }

        statusMessage = "Terminated \(process.name)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }

    func forceQuit(process: ProcessItem) {
        guard !process.isProtected else {
            statusMessage = "Cannot terminate protected system process"
            return
        }

        if let app = process.appRef {
            app.forceTerminate()
        } else {
            kill(process.id, SIGKILL)
        }

        statusMessage = "Force terminated \(process.name)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refresh()
        }
    }
}
