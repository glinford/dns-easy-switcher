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
            // If the persistent store cannot be created (e.g., corrupted store or permission issue),
            // fall back to an in-memory container so the app can still launch.
            let schema = Schema([
                DNSSettings.self,
                CustomDNSServer.self
            ])
            self.modelContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
            print("Warning: Using in-memory store due to ModelContainer error: \(error)")
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
