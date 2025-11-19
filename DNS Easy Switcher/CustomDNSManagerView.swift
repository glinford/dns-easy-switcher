//
//  CustomDNSManagerView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 25/02/2025.
//

import SwiftUI
import SwiftData

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
                                Text(server.servers.joined(separator: ", "))
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
}
