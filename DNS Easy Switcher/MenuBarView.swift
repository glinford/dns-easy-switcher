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
        @State private var showingAddDNS = false
    @State private var windowController: CustomSheetWindowController?
    
    var body: some View {
         Group {
             VStack {
                 Toggle("AdGuard DNS", isOn: Binding(
                     get: { dnsSettings.first?.isAdGuardEnabled ?? false },
                     set: { newValue in
                         if newValue && !isUpdating {
                             activateDNS(type: .adguard)
                         }
                     }
                   ))
                   .padding(.horizontal)
                   .disabled(isUpdating)
                 
                 Toggle("Cloudflare DNS", isOn: Binding(
                     get: { dnsSettings.first?.isCloudflareEnabled ?? false },
                     set: { newValue in
                         if newValue && !isUpdating {
                             activateDNS(type: .cloudflare)
                         }
                     }
                 ))
                 .padding(.horizontal)
                 .disabled(isUpdating)
                 
                 Toggle("Quad9 DNS", isOn: Binding(
                     get: { dnsSettings.first?.isQuad9Enabled ?? false },
                     set: { newValue in
                         if newValue && !isUpdating {
                             activateDNS(type: .quad9)
                         }
                     }
                 ))
                 .padding(.horizontal)
                 .disabled(isUpdating)
                 
                 if !customServers.isEmpty {
                     Divider()
                     
                     ForEach(customServers) { server in
                         Toggle(server.name, isOn: Binding(
                             get: { dnsSettings.first?.activeCustomDNSID == server.id },
                             set: { newValue in
                                 if newValue && !isUpdating {
                                     activateDNS(type: .custom(server))
                                 }
                             }
                         ))
                         .padding(.horizontal)
                         .disabled(isUpdating)
                         
                         Button("Remove") {
                             modelContext.delete(server)
                         }
                         .buttonStyle(.borderless)
                         .padding(.leading)
                     }
                 }
                 
                 Divider()
                 
                 Button(action: {
                                 showAddCustomDNSSheet()
                             }) {
                                 Text("Add Custom DNS")
                                     .frame(maxWidth: .infinity)
                             }
                             .buttonStyle(.bordered)
                             .padding(.horizontal)
                             .padding(.vertical, 5)
                 
                 Button("Disable DNS Override") {
                     if !isUpdating {
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
                 .disabled(isUpdating)
                 
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
    
    private func showAddCustomDNSSheet() {
         let addView = AddCustomDNSView { newServer in
             if let newServer = newServer {
                 modelContext.insert(newServer)
                 try? modelContext.save()
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
    
    enum DNSType: Equatable {
        case none
        case cloudflare
        case quad9
        case adguard
        case custom(CustomDNSServer)
        
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
    
    private func updateSettings(cloudflare: Bool, quad9: Bool, adguard: Bool) {
        if let settings = dnsSettings.first {
            settings.isCloudflareEnabled = cloudflare
            settings.isQuad9Enabled = quad9
            settings.isAdGuardEnabled = adguard
            settings.timestamp = Date()
            try? modelContext.save()
        }
    }

}
