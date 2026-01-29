//
//  CustomDNSHubView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 29/01/2026.
//

import SwiftUI
import SwiftData
import AppKit

struct CustomDNSHubView: View {
    enum Mode {
        case add
        case manage
    }

    let initialMode: Mode
    let activeCustomID: String?
    let autoActivateOnAdd: Bool
    let onUse: (CustomDNSServer) -> Void
    let onDisableActive: () -> Void
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomDNSServer.name) private var customServers: [CustomDNSServer]

    @State private var selectedID: String?
    @State private var isCreatingNew = false
    @State private var name = ""
    @State private var primaryDNS = ""
    @State private var secondaryDNS = ""
    @State private var tertiaryDNS = ""
    @State private var quaternaryDNS = ""
    @State private var showDeleteConfirm = false
    @State private var pendingDelete: CustomDNSServer?
    @State private var isTesting = false
    @State private var testResult: String?

    private enum UIConstants {
        static let cornerRadius: CGFloat = 16
        static let windowWidth: CGFloat = 720
        static let windowHeight: CGFloat = 460
        static let sidebarWidth: CGFloat = 220
        static let rowCornerRadius: CGFloat = 8
        static let rowPadding: CGFloat = 8
    }
    
    private let draftID = "__draft__"

    var body: some View {
        ZStack {
            glassBackground
                .overlay(
                    RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)

            HStack(spacing: 16) {
                sidebar
                Divider()
                editor
            }
            .padding(20)
        }
        .padding(12)
        .frame(width: UIConstants.windowWidth, height: UIConstants.windowHeight)
        .onAppear {
            initializeSelection()
        }
        .onChange(of: customServers.map(\.id), initial: false) { _, _ in
            synchronizeSelection()
        }
        .confirmationDialog("Delete custom DNS?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let server = pendingDelete {
                    delete(server)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected DNS entry from your list.")
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Custom DNS")
                    .font(.headline)
                Spacer()
                Button {
                    startNew()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if sidebarEntries.isEmpty {
                        Text("No custom DNS servers yet")
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(sidebarEntries) { entry in
                            Button {
                                if entry.isDraft {
                                    startNew()
                                } else if let server = entry.server {
                                    select(server)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title)
                                        .lineLimit(1)
                                    if let subtitle = entry.subtitle {
                                        Text(subtitle)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(UIConstants.rowPadding)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: UIConstants.rowCornerRadius, style: .continuous)
                                        .fill(selectedID == entry.id ? Color.accentColor.opacity(0.18) : Color.clear)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(width: UIConstants.sidebarWidth)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isCreatingNew ? "New Custom DNS" : "Edit Custom DNS")
                .font(.headline)

            TextField("Name (e.g. Work DNS)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Primary DNS (e.g. 8.8.8.8 or 127.0.0.1:5353)", text: $primaryDNS)
                .textFieldStyle(.roundedBorder)
                .help("Use comma to add multiple addresses. For custom ports on IPv4, add colon and port number (e.g., 127.0.0.1:5353)")

            TextField("Secondary DNS (optional)", text: $secondaryDNS)
                .textFieldStyle(.roundedBorder)
                .help("Use comma to add multiple addresses. For custom ports on IPv4, add colon and port number (e.g., 127.0.0.1:5353)")

            TextField("Third DNS (IPv6 or IPv4, optional)", text: $tertiaryDNS)
                .textFieldStyle(.roundedBorder)
                .help("Tip: bracket IPv6 if adding a port, e.g., [2001:4860:4860::8888]:5353")

            TextField("Fourth DNS (IPv6 or IPv4, optional)", text: $quaternaryDNS)
                .textFieldStyle(.roundedBorder)
                .help("Use comma to add multiple IPv6 entries if needed")

            HStack {
                Button("Test DNS") {
                    testDNS()
                }
                .disabled(primaryDNS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isTesting)

                if isTesting {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if let testResult = testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button("Use") {
                    if let server = currentServer {
                        onUse(server)
                    }
                }
                .disabled(currentServer == nil)

                Button("Delete", role: .destructive) {
                    if let server = currentServer {
                        pendingDelete = server
                        showDeleteConfirm = true
                    }
                }
                .disabled(currentServer == nil)

                Spacer()

                Button(isCreatingNew ? "Add" : "Save") {
                    save()
                }
                .keyboardShortcut(.return)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          primaryDNS.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var currentServer: CustomDNSServer? {
        guard let selectedID = selectedID, selectedID != draftID else { return nil }
        return customServers.first { $0.id == selectedID }
    }

    private struct SidebarEntry: Identifiable {
        let id: String
        let title: String
        let subtitle: String?
        let isDraft: Bool
        let server: CustomDNSServer?
    }

    private var sidebarEntries: [SidebarEntry] {
        var entries: [SidebarEntry] = []
        if isCreatingNew {
            let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(
                SidebarEntry(
                    id: draftID,
                    title: displayName.isEmpty ? "New DNS" : displayName,
                    subtitle: "Not saved yet",
                    isDraft: true,
                    server: nil
                )
            )
        }
        entries.append(contentsOf: customServers.map { server in
            SidebarEntry(
                id: server.id,
                title: server.name,
                subtitle: server.primaryDNS,
                isDraft: false,
                server: server
            )
        })
        return entries
    }

    private var glassBackground: some View {
        Group {
            if #available(macOS 12.0, *) {
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            } else {
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius, style: .continuous)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
            }
        }
    }

    private func initializeSelection() {
        if initialMode == .add {
            startNew()
            return
        }

        if let activeID = activeCustomID,
           let active = customServers.first(where: { $0.id == activeID }) {
            select(active)
        } else if let first = customServers.first {
            select(first)
        } else {
            startNew()
        }
    }

    private func synchronizeSelection() {
        if let selectedID = selectedID,
           selectedID == draftID {
            return
        }

        if let selectedID = selectedID,
           customServers.contains(where: { $0.id == selectedID }) {
            return
        }

        if let activeID = activeCustomID,
           let active = customServers.first(where: { $0.id == activeID }) {
            select(active)
        } else if let first = customServers.first, !isCreatingNew {
            select(first)
        } else if customServers.isEmpty {
            startNew()
        }
    }

    private func startNew() {
        isCreatingNew = true
        selectedID = draftID
        name = ""
        primaryDNS = ""
        secondaryDNS = ""
        tertiaryDNS = ""
        quaternaryDNS = ""
        testResult = nil
    }

    private func select(_ server: CustomDNSServer) {
        isCreatingNew = false
        selectedID = server.id
        name = server.name
        primaryDNS = server.primaryDNS
        secondaryDNS = server.secondaryDNS
        tertiaryDNS = server.tertiaryDNS ?? ""
        quaternaryDNS = server.quaternaryDNS ?? ""
        testResult = nil
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrimary = primaryDNS.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPrimary.isEmpty else { return }

        if isCreatingNew {
            let server = CustomDNSServer(
                name: trimmedName,
                primaryDNS: trimmedPrimary,
                secondaryDNS: secondaryDNS,
                tertiaryDNS: tertiaryDNS,
                quaternaryDNS: quaternaryDNS
            )
            modelContext.insert(server)
            saveContext(errorMessage: "Failed to save new DNS server")
            select(server)
            if autoActivateOnAdd {
                onUse(server)
            }
        } else if let server = currentServer {
            server.name = trimmedName
            server.primaryDNS = trimmedPrimary
            server.secondaryDNS = secondaryDNS
            server.tertiaryDNS = tertiaryDNS
            server.quaternaryDNS = quaternaryDNS
            saveContext(errorMessage: "Failed to save DNS server changes")

            if activeCustomID == server.id {
                onUse(server)
            }
        }
    }

    private func delete(_ server: CustomDNSServer) {
        modelContext.delete(server)
        saveContext(errorMessage: "Failed to save after deleting DNS server")

        if activeCustomID == server.id {
            onDisableActive()
        }

        pendingDelete = nil
        DispatchQueue.main.async {
            synchronizeSelection()
        }
    }

    private func saveContext(errorMessage: String) {
        do {
            try modelContext.save()
        } catch {
            print("\(errorMessage): \(error)")
        }
    }

    private func testDNS() {
        let host = hostForPing(primaryDNS)
        guard !host.isEmpty else { return }
        isTesting = true
        testResult = nil
        DNSSpeedTester.shared.testServer(server: host) { latency, success in
            DispatchQueue.main.async {
                isTesting = false
                testResult = success ? "Latency: \(Int(latency))ms" : "Timeout"
            }
        }
    }

    private func hostForPing(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(separator: ",", maxSplits: 1).first else { return "" }
        let entry = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entry.isEmpty else { return "" }

        if entry.hasPrefix("["),
           let close = entry.firstIndex(of: "]") {
            let inside = entry.index(after: entry.startIndex)..<close
            return String(entry[inside])
        }

        let colonCount = entry.filter { $0 == ":" }.count
        if colonCount == 1, let idx = entry.firstIndex(of: ":") {
            return String(entry[..<idx])
        }

        return entry
    }
}
