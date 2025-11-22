//
//  MenuBarView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//
import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [DNSSettings]
    @Query(sort: \CustomDNSServer.name) private var customServers: [CustomDNSServer]

    @State private var isUpdating = false
    @State private var isSpeedTesting = false
    @State private var pingResults: [DNSSpeedTester.PingResult] = []
    @State private var aboutWindowController: CustomSheetWindowController?
    @State private var windowController: CustomSheetWindowController?

    private var activeServerID: String? {
        settings.first?.activeServerID
    }

    // Enum to differentiate server types for activation logic
    enum DNSType {
        case predefined(PredefinedDNSServer)
        case custom(CustomDNSServer)
    }

    var body: some View {
        Group {
            VStack {
                // No DNS Override Button
                Button(action: {
                    if !isUpdating && !isSpeedTesting {
                        isUpdating = true
                        DNSManager.shared.disableDNS { success in
                            if success {
                                updateActiveServer(id: nil)
                            }
                            isUpdating = false
                        }
                    }
                }) {
                    HStack {
                        Text("<No DNS Override>")
                        Spacer()
                        if activeServerID == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)

                // Predefined DNS Servers
                ForEach(DNSManager.predefinedServers) { server in
                    Button(action: {
                        activateDNS(type: .predefined(server))
                    }) {
                        HStack {
                            Text(getLabelWithPing(server.name, for: server.id))
                            Spacer()
                            if activeServerID == server.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .disabled(isUpdating || isSpeedTesting)
                }

                // GetFlix DNS Menu
                Menu {
                    ForEach(DNSManager.getflixServers) { server in
                        Button(action: {
                            activateDNS(type: .predefined(server))
                        }) {
                            HStack {
                                Text(getLabelWithPing(server.name, for: server.id))
                                Spacer()
                                if activeServerID == server.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("GetFlix DNS")
                        Spacer()
                        if activeServerID?.hasPrefix("getflix-") == true {
                            Image(systemName: "checkmark")
                        }
                        if isSpeedTesting {
                            ProgressView().scaleEffect(0.6).frame(width: 12, height: 12).padding(.trailing, 4)
                        }
                    }
                }
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)

                // Custom DNS menu
                if !customServers.isEmpty {
                    Menu {
                        ForEach(customServers) { server in
                            Button(action: {
                                activateDNS(type: .custom(server))
                            }) {
                                HStack {
                                    Text(getLabelWithPing(server.name, for: server.id))
                                    Spacer()
                                    if activeServerID == server.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Custom DNS")
                            Spacer()
                            if let activeID = activeServerID, customServers.contains(where: { $0.id == activeID }) {
                                Image(systemName: "checkmark")
                            }
                            if isSpeedTesting {
                                ProgressView().scaleEffect(0.6).frame(width: 12, height: 12).padding(.trailing, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .disabled(isUpdating || isSpeedTesting)
                }

                Divider()

                // Tool Section
                Button(action: {
                    showManageCustomDNSSheet()
                }) {
                    Text("Manage Custom DNS")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .disabled(isSpeedTesting)

                Button(action: {
                    runSpeedTest()
                }) {
                    HStack {
                        Text("Run Speed Test")
                        if isSpeedTesting {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .disabled(isUpdating || isSpeedTesting)

                Button(action: {
                    clearDNSCache()
                }) {
                    HStack {
                        Text("Clear DNS Cache")
                        if isUpdating {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 16, height: 16)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .disabled(isUpdating || isSpeedTesting)

                Divider()

                Button("About") {
                    showAboutSheet()
                }
                .padding(.vertical, 5)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.vertical, 5)
            }
            .padding(.vertical, 5)
        }
        .onAppear {
            ensureSettingsExist()
        }
    }

    private func getLabelWithPing(_ baseLabel: String, for serverId: String) -> String {
        guard !pingResults.isEmpty, let result = pingResults.first(where: { $0.id == serverId }) else {
            return baseLabel
        }
        return "\(baseLabel) (\(Int(result.responseTime))ms)"
    }

    private func runSpeedTest() {
        guard !isSpeedTesting else { return }
        isSpeedTesting = true
        pingResults = []

        let allPredefined = DNSManager.predefinedServers + DNSManager.getflixServers

        Task {
            await DNSSpeedTester.shared.testAllDNS(predefinedServers: allPredefined, customServers: customServers) { results in
                // Completion is already on MainActor from DNSSpeedTester
                self.pingResults = results
                self.isSpeedTesting = false
            }
        }
    }

    private func showManageCustomDNSSheet() {
        if let window = windowController?.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let manageView = CustomDNSManagerView(onClose: {
            self.windowController?.close()
            self.windowController = nil
        })
        .modelContext(modelContext)

        windowController = CustomSheetWindowController(view: manageView, title: "Manage Custom DNS")
        windowController?.window?.level = .floating
        windowController?.showWindow(nil)
    }

    private func activateDNS(type: DNSType) {
        isUpdating = true

        let completion = { (success: Bool, id: String) in
            if success {
                self.updateActiveServer(id: id)
            }
            self.isUpdating = false
        }

        switch type {
        case .predefined(let server):
            DNSManager.shared.setDNS(servers: server.servers) { success in
                completion(success, server.id)
            }
        case .custom(let server):
            DNSManager.shared.setDNS(servers: server.servers) { success in
                completion(success, server.id)
            }
        }
    }

    private func updateActiveServer(id: String?) {
        if let settings = settings.first {
            settings.activeServerID = id
            settings.timestamp = Date()
            try? modelContext.save()
        }
    }

    private func ensureSettingsExist() {
        if settings.isEmpty {
            modelContext.insert(DNSSettings())
            try? modelContext.save()
        }
    }

    private func clearDNSCache() {
        if !isUpdating && !isSpeedTesting {
            isUpdating = true
            DNSManager.shared.clearDNSCache { success in
                DispatchQueue.main.async {
                    self.isUpdating = false
                }
            }
        }
    }

    private func showAboutSheet() {
        let aboutView = AboutView {
            aboutWindowController?.close()
            aboutWindowController = nil
        }

        aboutWindowController?.close()
        aboutWindowController = CustomSheetWindowController(view: aboutView, title: "About")
        aboutWindowController?.window?.level = .floating
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.center()
    }

}
