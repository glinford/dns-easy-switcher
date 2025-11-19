//
//  EditCustomDNSView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 25/02/2025.
//

import SwiftUI

struct EditCustomDNSView: View {
    let server: CustomDNSServer
    var onComplete: (CustomDNSServer?) -> Void

    @State private var name: String
    @State private var servers: [String]

    init(server: CustomDNSServer, onComplete: @escaping (CustomDNSServer?) -> Void) {
        self.server = server
        self.onComplete = onComplete
        _name = State(initialValue: server.name)
        _servers = State(initialValue: server.servers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name (e.g. Work DNS)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Primary DNS (e.g. 8.8.8.8 or 127.0.0.1:5353)", text: $servers[0])
                .textFieldStyle(.roundedBorder)
                .help("For custom ports, add colon and port number (e.g., 127.0.0.1:5353)")

            TextField("Secondary DNS (optional)", text: $servers[1])
                .textFieldStyle(.roundedBorder)
                .help("For custom ports, add colon and port number (e.g., 127.0.0.1:5353)")

            HStack {
                Button("Cancel") {
                    onComplete(nil)
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Save") {
                    guard !name.isEmpty && !servers[0].isEmpty else { return }
                    let updatedServer = CustomDNSServer(
                        id: server.id,
                        name: name,
                        servers: servers.filter { !$0.isEmpty }, // Filter out empty strings
                        timestamp: server.timestamp
                    )
                    onComplete(updatedServer)
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || servers[0].isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
