//
//  AboutView.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 27/02/2025.
//

import SwiftUI

struct AboutView: View {
    var onClose: () -> Void
    
    private var versionText: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return buildNumber.isEmpty ? "Version \(shortVersion)" : "Version \(shortVersion) (\(buildNumber))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DNS Easy Switcher")
                .font(.headline)
            
            Text(versionText)
                .foregroundColor(.secondary)
            
            Link("GitHub — glinford/dns-easy-switcher", destination: URL(string: "https://github.com/glinford/dns-easy-switcher")!)
            
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
        .frame(width: 320)
    }
}
