//
//  CustomDNSView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import SwiftUI
import SwiftData

struct CustomDNSFormView: View {
    let existingServer: CustomDNSServer?
    var onComplete: (CustomDNSServer?) -> Void

    @State private var name: String
    @State private var serversLine: String

    private var primaryTitle: String { existingServer == nil ? "Add" : "Save" }

    init(existingServer: CustomDNSServer?, onComplete: @escaping (CustomDNSServer?) -> Void) {
        self.existingServer = existingServer
        self.onComplete = onComplete
        _name = State(initialValue: existingServer?.name ?? "")
        _serversLine = State(initialValue: (existingServer?.servers ?? []).joined(separator: " "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Name (e.g. Work DNS)", text: $name)
                .textFieldStyle(.roundedBorder)

            TextField("Space-separated DNS servers (e.g. 8.8.8.8 8.8.4.4)", text: $serversLine)
                .textFieldStyle(.roundedBorder)
                .help("Each server has an IPv4 or IPv6 address and an optional :port (e.g. 127.0.0.1:5353)")

            HStack {
                Button("Cancel") {
                    onComplete(nil)
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button(primaryTitle) {
                    let parts = serversLine.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    guard !name.isEmpty && !parts.isEmpty else { return }
                    let server: CustomDNSServer
                    if let existingServer {
                        server = CustomDNSServer(
                            id: existingServer.id,
                            name: name,
                            servers: parts,
                            timestamp: existingServer.timestamp
                        )
                    } else {
                        server = CustomDNSServer(
                            name: name,
                            servers: parts
                        )
                    }
                    onComplete(server)
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || serversLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

struct AddCustomDNSView: View {
    var onComplete: (CustomDNSServer?) -> Void

    var body: some View {
        CustomDNSFormView(existingServer: nil, onComplete: onComplete)
        .padding()
        .frame(width: 350)
    }
}

struct EditCustomDNSView: View {
    let server: CustomDNSServer
    var onComplete: (CustomDNSServer?) -> Void

    var body: some View {
        CustomDNSFormView(existingServer: server, onComplete: onComplete)
        .padding()
        .frame(width: 350)
    }
}
