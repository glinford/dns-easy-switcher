//
//  CustomDNSManagerView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 25/02/2025.
//

import SwiftUI

enum CustomDNSAction {
    case use, edit, delete
}

struct CustomDNSManagerView: View {
    let customServers: [CustomDNSServer]
    let onAction: (CustomDNSAction, CustomDNSServer) -> Void
    let onClose: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Manage Custom DNS")
                .font(.headline)
                .padding(.bottom, 4)
            
            if customServers.isEmpty {
                Text("No custom DNS servers added")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 12)
            } else {
                List {
                    ForEach(customServers) { server in
                        HStack {
                            Text(server.name)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: {
                                onAction(.edit, server)
                            }) {
                                Image(systemName: "pencil")
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .help("Edit this DNS")
                            .padding(.trailing, 8)
                            
                            Button(action: {
                                onAction(.delete, server)
                            }) {
                                Image(systemName: "trash")
                                    .frame(width: 16, height: 16)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            .help("Delete this DNS")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .frame(minHeight: 100, maxHeight: 200)
                .listStyle(.plain)
            }
            
            HStack {
                Spacer()
                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 300)
    }
}
