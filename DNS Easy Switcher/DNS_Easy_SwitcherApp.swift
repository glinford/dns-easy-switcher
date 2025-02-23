//
//  DNS_Easy_SwitcherApp.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct DNS_Easy_SwitcherApp: App {
    @StateObject private var menuBarController = MenuBarController()
    
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                DNSSettings.self,
                CustomDNSServer.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "hidden") {
            Color.clear
                .frame(width: 0, height: 0)
                .hidden()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 0, height: 0)
        .modelContainer(modelContainer)
        
        MenuBarExtra("DNS Switcher", systemImage: "network") {
            MenuBarView()
                .environment(\.modelContext, modelContainer.mainContext)
                .frame(width: 300)
        }
    }
}
