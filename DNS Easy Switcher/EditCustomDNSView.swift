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
    @State private var primaryDNS: String
    @State private var secondaryDNS: String
    @State private var tertiaryDNS: String
    @State private var quaternaryDNS: String
    
    init(server: CustomDNSServer, onComplete: @escaping (CustomDNSServer?) -> Void) {
        self.server = server
        self.onComplete = onComplete
        _name = State(initialValue: server.name)
        _primaryDNS = State(initialValue: server.primaryDNS)
        _secondaryDNS = State(initialValue: server.secondaryDNS)
        _tertiaryDNS = State(initialValue: server.tertiaryDNS ?? "")
        _quaternaryDNS = State(initialValue: server.quaternaryDNS ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                Button("Cancel") {
                    onComplete(nil)
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    guard !name.isEmpty && !primaryDNS.isEmpty else { return }
                    let updatedServer = CustomDNSServer(
                        id: server.id,
                        name: name,
                        primaryDNS: primaryDNS,
                        secondaryDNS: secondaryDNS,
                        tertiaryDNS: tertiaryDNS,
                        quaternaryDNS: quaternaryDNS,
                        timestamp: server.timestamp
                    )
                    onComplete(updatedServer)
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || primaryDNS.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}
