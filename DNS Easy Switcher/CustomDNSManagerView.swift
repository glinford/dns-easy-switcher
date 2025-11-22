//
//  CustomDNSManagerView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 25/02/2025.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct CustomDNSManagerView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomDNSServer.name) private var customServers: [CustomDNSServer]

    let onClose: () -> Void

    @State private var selectedServerID: CustomDNSServer.ID?
    @State private var showingAddSheet = false
    @State private var serverToEdit: CustomDNSServer?
    @State private var serverToDelete: CustomDNSServer? // New state variable for confirmation

    private var selectedServer: CustomDNSServer? {
        guard let selectedServerID = selectedServerID else { return nil }
        return customServers.first { $0.id == selectedServerID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if customServers.isEmpty {
                Text("No custom DNS servers added")
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedServerID) {
                    ForEach(customServers) { server in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(server.name).fontWeight(.bold)
                                Text(server.servers.joined(separator: "   "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .tag(server.id)
                        .onTapGesture(count: 2) {
                            serverToEdit = server
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }

            HStack(spacing: 8) {
                Button(action: {
                    showingAddSheet = true
                }) {
                    Image(systemName: "plus")
                        .frame(width: 16, height: 16)
                }
                .help("Add a new DNS")

                Button(action: {
                    if let server = selectedServer {
                        serverToDelete = server // Set serverToDelete to show confirmation dialog
                    }
                }) {
                    Image(systemName: "minus") // Changed to minus
                        .frame(width: 16, height: 16)
                }
                .disabled(selectedServerID == nil)
                .help("Remove selected DNS")

                Button(action: {
                    if let server = selectedServer {
                        serverToEdit = server
                    }
                }) {
                    Image(systemName: "pencil")
                        .frame(width: 16, height: 16)
                }
                .disabled(selectedServerID == nil)
                .help("Edit selected DNS")

                Spacer()

                Button(action: { exportCustomDNS() }) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 16, height: 16)
                }
                .help("Export custom DNS to a text file")

                Button(action: { importCustomDNS() }) {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 16, height: 16)
                }
                .help("Import custom DNS from a text file")
            }
            .padding()
        }
        .frame(minWidth: 250, minHeight: 150)
        .sheet(isPresented: $showingAddSheet) {
            AddCustomDNSView { newServer in
                if let newServer = newServer {
                    modelContext.insert(newServer)
                    try? modelContext.save()
                }
                showingAddSheet = false
            }
        }
        .sheet(item: $serverToEdit) { server in
            EditCustomDNSView(server: server) { updatedServer in
                if let updatedServer = updatedServer {
                    server.name = updatedServer.name
                    server.servers = updatedServer.servers
                    try? modelContext.save()
                }
                serverToEdit = nil
            }
        }
        .confirmationDialog("Confirm Deletion", isPresented: Binding(
            get: { serverToDelete != nil },
            set: { if !$0 { serverToDelete = nil } }
        ), presenting: serverToDelete) { server in
            Button("Delete", role: .destructive) {
                delete(server: server)
                serverToDelete = nil
                selectedServerID = nil // Deselect after deletion
            }
            Button("Cancel", role: .cancel) {
                serverToDelete = nil
            }
        } message: { server in
            Text("Are you sure you want to delete the DNS server '\(server.name)'?")
        }
    }

    private func delete(server: CustomDNSServer) {
        modelContext.delete(server)
        try? modelContext.save()
    }

    private func exportCustomDNS() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "CustomDNS.txt"
        if panel.runModal() == .OK, let url = panel.url {
            let lines = customServers.map { server in
                let serversList = server.servers.joined(separator: " ")
                let escapedName = escapeName(server.name)
                return "\(escapedName): \(serversList)"
            }.joined(separator: "\n")
            do {
                try lines.write(to: url, atomically: true, encoding: .utf8)
            } catch {
            }
        }
    }

    private func importCustomDNS() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    guard let colon = indexOfUnescapedColon(in: trimmed) else { continue }
                    let rawName = String(trimmed[..<colon]).trimmingCharacters(in: .whitespaces)
                    let name = unescapeName(rawName)
                    let serversString = String(trimmed[trimmed.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                    let parts = serversString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    if parts.isEmpty { continue }

                    if let existing = customServers.first(where: { $0.name == name }) {
                        existing.servers = parts
                    } else {
                        let newServer = CustomDNSServer(name: name, servers: parts)
                        modelContext.insert(newServer)
                    }
                }
                try? modelContext.save()
            } catch {
            }
        }
    }

    private func escapeName(_ name: String) -> String {
        var s = name.replacingOccurrences(of: "\\", with: "\\\\")
        s = s.replacingOccurrences(of: ":", with: "\\:")
        return s
    }

    private func unescapeName(_ s: String) -> String {
        var result = ""
        var iterator = s.makeIterator()
        var prevWasEscape = false
        while let ch = iterator.next() {
            if prevWasEscape {
                result.append(ch)
                prevWasEscape = false
            } else if ch == "\\" {
                prevWasEscape = true
            } else {
                result.append(ch)
            }
        }
        if prevWasEscape { result.append("\\") }
        return result
    }

    private func indexOfUnescapedColon(in s: String) -> String.Index? {
        var prevWasEscape = false
        for idx in s.indices {
            let ch = s[idx]
            if prevWasEscape {
                prevWasEscape = false
                continue
            }
            if ch == "\\" { prevWasEscape = true; continue }
            if ch == ":" { return idx }
        }
        return nil
    }
}
