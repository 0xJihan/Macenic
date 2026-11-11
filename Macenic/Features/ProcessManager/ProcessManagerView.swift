import SwiftUI

struct ProcessManagerView: View {
    @Bindable var service: ProcessManagerService
    @State private var confirmingForceQuitProcess: ProcessItem?

    var body: some View {
        VStack(spacing: 0) {
            topControls
            Divider()
            headersBar
            Divider()

            if service.filteredProcesses.isEmpty {
                emptyState
            } else {
                processList
            }

            if let message = service.statusMessage {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 10))
                    Text(message)
                        .font(.system(size: 10))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { service.startPolling() }
        .onDisappear { service.stopPolling() }
        .confirmationDialog(
            "Force Quit Process",
            isPresented: Binding(
                get: { confirmingForceQuitProcess != nil },
                set: { if !$0 { confirmingForceQuitProcess = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let target = confirmingForceQuitProcess {
                Button("Force Quit \(target.name)", role: .destructive) {
                    service.forceQuit(process: target)
                    confirmingForceQuitProcess = nil
                }
                Button("Cancel", role: .cancel) {
                    confirmingForceQuitProcess = nil
                }
            }
        } message: {
            if let target = confirmingForceQuitProcess {
                Text("Are you sure you want to force quit \(target.name) (PID \(target.id))? Any unsaved changes will be lost.")
            }
        }
    }

    private var topControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                TextField("Search name or PID...", text: $service.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !service.searchQuery.isEmpty {
                    Button {
                        service.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Picker("", selection: $service.filterOption) {
                    ForEach(ProcessFilterOption.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Menu {
                    ForEach(ProcessSortOption.allCases) { opt in
                        Button {
                            if service.sortOption == opt {
                                service.sortAscending.toggle()
                            } else {
                                service.sortOption = opt
                                service.sortAscending = false
                            }
                        } label: {
                            HStack {
                                Text(opt.rawValue)
                                if service.sortOption == opt {
                                    Image(systemName: service.sortAscending ? "arrow.up" : "arrow.down")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Sort: \(service.sortOption.rawValue)")
                            .font(.system(size: 10))
                        Image(systemName: service.sortAscending ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var headersBar: some View {
        HStack {
            Text("Process")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("PID")
                .frame(width: 48, alignment: .trailing)
            Text("RAM")
                .frame(width: 60, alignment: .trailing)
            Text("CPU")
                .frame(width: 48, alignment: .trailing)
            Text("Actions")
                .frame(width: 50, alignment: .trailing)
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.15))
    }

    private var processList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(service.filteredProcesses) { item in
                    processRow(item)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func processRow(_ item: ProcessItem) -> some View {
        HStack(spacing: 6) {
            if let icon = item.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: item.isApp ? "app" : "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }

            Text(item.name)
                .font(.system(size: 11, weight: item.isApp ? .medium : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(item.id)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 48, alignment: .trailing)

            Text(ByteFormatter.format(item.memoryBytes))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Text(String(format: "%.1f%%", item.cpuUsage))
                .font(.system(size: 10, weight: item.cpuUsage > 10 ? .semibold : .regular, design: .monospaced))
                .foregroundStyle(item.cpuUsage > 50 ? .red : item.cpuUsage > 20 ? .orange : .secondary)
                .frame(width: 48, alignment: .trailing)

            HStack(spacing: 2) {
                if !item.isProtected {
                    Menu {
                        if item.isApp {
                            Button("Bring to Front") {
                                service.activate(process: item)
                            }
                            if item.appRef?.bundleURL != nil {
                                Button("Reveal in Finder") {
                                    service.revealInFinder(process: item)
                                }
                            }
                            Divider()
                        }
                        Button("Quit") {
                            service.quit(process: item)
                        }
                        Button("Force Quit...", role: .destructive) {
                            confirmingForceQuitProcess = item
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 20)
                } else {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20)
                        .help("Protected system process")
                }
            }
            .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "cpu")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text(service.searchQuery.isEmpty ? "No processes found" : "No matches for \"\(service.searchQuery)\"")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
