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
    @Query(sort: \DNSSettings.timestamp) private var dnsSettings: [DNSSettings]
    @Query(sort: \CustomDNSServer.name) private var customServers: [CustomDNSServer]
    @State private var isUpdating = false
    @State private var isSpeedTesting = false
    @State private var pingResults: [DNSSpeedTester.PingResult] = []
    @State private var showingAddDNS = false
    @State private var showingManageDNS = false
    @State private var selectedServer: CustomDNSServer?
    @State private var windowController: CustomSheetWindowController?
    
    var body: some View {
        Group {
            VStack {
                // Cloudflare DNS
                Toggle(getLabelWithPing("Cloudflare DNS", dnsType: .cloudflare), isOn: Binding(
                    get: { dnsSettings.first?.isCloudflareEnabled ?? false },
                    set: { newValue in
                        if newValue && !isUpdating {
                            activateDNS(type: .cloudflare)
                        }
                    }
                ))
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)
                .overlay(alignment: .trailing) {
                    if isSpeedTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                            .padding(.trailing, 8)
                    }
                }
                
                // Quad9 DNS
                Toggle(getLabelWithPing("Quad9 DNS", dnsType: .quad9), isOn: Binding(
                    get: { dnsSettings.first?.isQuad9Enabled ?? false },
                    set: { newValue in
                        if newValue && !isUpdating {
                            activateDNS(type: .quad9)
                        }
                    }
                ))
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)
                .overlay(alignment: .trailing) {
                    if isSpeedTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                            .padding(.trailing, 8)
                    }
                }
                
                // AdGuard DNS
                Toggle(getLabelWithPing("AdGuard DNS", dnsType: .adguard), isOn: Binding(
                    get: { dnsSettings.first?.isAdGuardEnabled ?? false },
                    set: { newValue in
                        if newValue && !isUpdating {
                            activateDNS(type: .adguard)
                        }
                    }
                ))
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)
                .overlay(alignment: .trailing) {
                    if isSpeedTesting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                            .padding(.trailing, 8)
                    }
                }
                
                // GetFlix DNS Menu
                Menu {
                    ForEach(Array(DNSManager.shared.getflixServers.keys.sorted()), id: \.self) { location in
                        Button(action: {
                            activateDNS(type: .getflix(location))
                        }) {
                            HStack {
                                Text(getGetflixLabelWithPing(location))
                                Spacer()
                                if dnsSettings.first?.activeGetFlixLocation == location {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("GetFlix DNS")
                        Spacer()
                        if let activeLocation = dnsSettings.first?.activeGetFlixLocation {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                        }
                        if isSpeedTesting {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                                .padding(.trailing, 4)
                        }
                        Image(systemName: "chevron.down")
                    }
                }
                .padding(.horizontal)
                .disabled(isUpdating || isSpeedTesting)
                
                Divider()
                
                // Custom DNS section
                if !customServers.isEmpty {
                    Menu {
                        ForEach(customServers) { server in
                            Button(action: {
                                activateDNS(type: .custom(server))
                            }) {
                                HStack {
                                    Text(getCustomDNSLabelWithPing(server))
                                    Spacer()
                                    if dnsSettings.first?.activeCustomDNSID == server.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text("Custom DNS")
                            Spacer()
                            if dnsSettings.first?.activeCustomDNSID != nil {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                            }
                            if isSpeedTesting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                    .padding(.trailing, 4)
                            }
                            Image(systemName: "chevron.down")
                        }
                    }
                    .padding(.horizontal)
                    .disabled(isUpdating || isSpeedTesting)
                    
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
                }
                
                Button(action: {
                    showAddCustomDNSSheet()
                }) {
                    Text("Add Custom DNS")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .disabled(isSpeedTesting)
                
                Divider()
                
                Button("Disable DNS Override") {
                    if !isUpdating && !isSpeedTesting {
                        isUpdating = true
                        DNSManager.shared.disableDNS { success in
                            if success {
                                Task { @MainActor in
                                    updateSettings(type: .none)
                                }
                            }
                            isUpdating = false
                        }
                    }
                }
                .padding(.vertical, 5)
                .disabled(isUpdating || isSpeedTesting)
                
                // Speed Test Button
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
                
                Divider()
                
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
    
    // Helper methods for getting ping results
    private func getLabelWithPing(_ baseLabel: String, dnsType: DNSType) -> String {
        guard !pingResults.isEmpty else { return baseLabel }
        
        switch dnsType {
        case .cloudflare:
            if let result = pingResults.first(where: { $0.dnsName == "Cloudflare" }) {
                return "\(baseLabel) (\(Int(result.responseTime))ms)"
            }
        case .quad9:
            if let result = pingResults.first(where: { $0.dnsName == "Quad9" }) {
                return "\(baseLabel) (\(Int(result.responseTime))ms)"
            }
        case .adguard:
            if let result = pingResults.first(where: { $0.dnsName == "AdGuard" }) {
                return "\(baseLabel) (\(Int(result.responseTime))ms)"
            }
        default:
            break
        }
        
        return baseLabel
    }
    
    private func getGetflixLabelWithPing(_ location: String) -> String {
        guard !pingResults.isEmpty else { return location }
        
        if let result = pingResults.first(where: { $0.dnsName == "Getflix: \(location)" }) {
            return "\(location) (\(Int(result.responseTime))ms)"
        }
        
        return location
    }
    
    private func getCustomDNSLabelWithPing(_ server: CustomDNSServer) -> String {
        guard !pingResults.isEmpty else { return server.name }
        
        if let result = pingResults.first(where: { $0.isCustom && $0.customID == server.id }) {
            return "\(server.name) (\(Int(result.responseTime))ms)"
        }
        
        return server.name
    }
    
    // Run DNS speed test
    private func runSpeedTest() {
        guard !isSpeedTesting else { return }
        
        isSpeedTesting = true
        pingResults = []
        
        DNSSpeedTester.shared.testAllDNS(customServers: customServers) { results in
            self.pingResults = results
            self.isSpeedTesting = false
        }
    }
    
    private func showAddCustomDNSSheet() {
        let addView = AddCustomDNSView { newServer in
            if let newServer = newServer {
                modelContext.insert(newServer)
                try? modelContext.save()
                // Automatically activate the new DNS
                activateDNS(type: .custom(newServer))
            }
            windowController?.close()
            windowController = nil
        }
        
        windowController = CustomSheetWindowController(view: addView, title: "Add Custom DNS")
        windowController?.window?.level = .floating
        windowController?.showWindow(nil)
        
        // Position the window relative to the menu bar
        if let window = windowController?.window,
           let screenFrame = NSScreen.main?.frame {
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: screenFrame.width - windowFrame.width - 20,
                y: screenFrame.height - 40 - windowFrame.height
            )
            window.setFrameTopLeftPoint(newOrigin)
        }
    }
    
    private func showManageCustomDNSSheet() {
        let manageView = CustomDNSManagerView(customServers: customServers) { action, server in
            switch action {
            case .edit:
                editCustomDNS(server)
            case .delete:
                modelContext.delete(server)
                try? modelContext.save()
                
                // If this was the active server, disable DNS
                if dnsSettings.first?.activeCustomDNSID == server.id {
                    isUpdating = true
                    DNSManager.shared.disableDNS { success in
                        if success {
                            Task { @MainActor in
                                updateSettings(type: .none)
                            }
                        }
                        isUpdating = false
                    }
                }
            case .use:
                activateDNS(type: .custom(server))
            }
            
            // Don't close the window for .use or .edit actions
            if action == .delete {
                windowController?.close()
                windowController = nil
            }
        }
        
        windowController = CustomSheetWindowController(view: manageView, title: "Manage Custom DNS")
        windowController?.window?.level = .floating
        windowController?.showWindow(nil)
        
        // Position the window relative to the menu bar
        if let window = windowController?.window,
           let screenFrame = NSScreen.main?.frame {
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: screenFrame.width - windowFrame.width - 20,
                y: screenFrame.height - 40 - windowFrame.height
            )
            window.setFrameTopLeftPoint(newOrigin)
        }
    }
    
    private func editCustomDNS(_ server: CustomDNSServer) {
        let editView = EditCustomDNSView(server: server) { updatedServer in
            if let updatedServer = updatedServer {
                // Update existing server properties
                server.name = updatedServer.name
                server.primaryDNS = updatedServer.primaryDNS
                server.secondaryDNS = updatedServer.secondaryDNS
                try? modelContext.save()
                
                // If this was the active server, update DNS settings
                if dnsSettings.first?.activeCustomDNSID == server.id {
                    activateDNS(type: .custom(server))
                }
            }
            
            windowController?.close()
            windowController = nil
        }
        
        windowController?.close()
        
        windowController = CustomSheetWindowController(view: editView, title: "Edit Custom DNS")
        windowController?.window?.level = .floating
        windowController?.showWindow(nil)
        
        // Position the window relative to the menu bar
        if let window = windowController?.window,
           let screenFrame = NSScreen.main?.frame {
            let windowFrame = window.frame
            let newOrigin = NSPoint(
                x: screenFrame.width - windowFrame.width - 20,
                y: screenFrame.height - 40 - windowFrame.height
            )
            window.setFrameTopLeftPoint(newOrigin)
        }
    }
    
    enum DNSType: Equatable {
        case none
        case cloudflare
        case quad9
        case adguard
        case custom(CustomDNSServer)
        case getflix(String)
        
        static func == (lhs: DNSType, rhs: DNSType) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.cloudflare, .cloudflare):
                return true
            case (.quad9, .quad9):
                return true
            case (.adguard, .adguard):
                return true
            case (.custom(let lServer), .custom(let rServer)):
                return lServer.id == rServer.id
            case (.getflix(let lLocation), .getflix(let rLocation)):
                return lLocation == rLocation
            default:
                return false
            }
        }
    }
    
    private func activateDNS(type: DNSType) {
        isUpdating = true
        
        switch type {
        case .cloudflare:
            DNSManager.shared.setPredefinedDNS(dnsServers: DNSManager.shared.cloudflareServers) { success in
                if success {
                    Task { @MainActor in
                        updateSettings(type: type)
                    }
                }
                isUpdating = false
            }
        case .quad9:
            DNSManager.shared.setPredefinedDNS(dnsServers: DNSManager.shared.quad9Servers) { success in
                if success {
                    Task { @MainActor in
                        updateSettings(type: type)
                    }
                }
                isUpdating = false
            }
        case .adguard:
            DNSManager.shared.setPredefinedDNS(dnsServers: DNSManager.shared.adguardServers) { success in
                if success {
                    Task { @MainActor in
                        updateSettings(type: type)
                    }
                }
                isUpdating = false
            }
        case .custom(let server):
            DNSManager.shared.setCustomDNS(primary: server.primaryDNS, secondary: server.secondaryDNS) { success in
                if success {
                    Task { @MainActor in
                        updateSettings(type: type)
                    }
                }
                isUpdating = false
            }
        case .getflix(let location):
            if let dnsServer = DNSManager.shared.getflixServers[location] {
                DNSManager.shared.setCustomDNS(primary: dnsServer, secondary: "") { success in
                    if success {
                        Task { @MainActor in
                            updateSettings(type: type)
                        }
                    }
                    isUpdating = false
                }
            }
        case .none:
            updateSettings(type: type)
            isUpdating = false
        }
    }
    
    private func updateSettings(type: DNSType) {
        if let settings = dnsSettings.first {
            settings.isCloudflareEnabled = (type == .cloudflare)
            settings.isQuad9Enabled = (type == .quad9)
            settings.isAdGuardEnabled = type == .adguard ? true : nil
            
            if case .getflix(let location) = type {
                settings.activeGetFlixLocation = location
            } else {
                settings.activeGetFlixLocation = nil
            }
            
            if case .custom(let server) = type {
                settings.activeCustomDNSID = server.id
            } else {
                settings.activeCustomDNSID = nil
            }
            
            settings.timestamp = Date()
        }
    }
    
    private func ensureSettingsExist() {
        if dnsSettings.isEmpty {
            modelContext.insert(DNSSettings())
            try? modelContext.save()
        }
    }
}
