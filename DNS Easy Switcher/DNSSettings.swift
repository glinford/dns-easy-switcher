//
//  DNSSettings.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import SwiftData

@Model
final class CustomDNSServer: Identifiable {
    var id: String
    var name: String
    var primaryDNS: String
    var secondaryDNS: String
    var tertiaryDNS: String?
    var quaternaryDNS: String?
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         name: String,
         primaryDNS: String,
         secondaryDNS: String,
         tertiaryDNS: String? = nil,
         quaternaryDNS: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.primaryDNS = primaryDNS
        self.secondaryDNS = secondaryDNS
        self.tertiaryDNS = tertiaryDNS
        self.quaternaryDNS = quaternaryDNS
        self.timestamp = timestamp
    }
}

@Model
final class DNSSettings {
    @Attribute(.unique) var id: String
    var isCloudflareEnabled: Bool
    var isQuad9Enabled: Bool
    var activeCustomDNSID: String?
    var timestamp: Date
    var activeGetFlixLocation: String?
    var isAdGuardEnabled: Bool?
    
    init(id: String = UUID().uuidString,
         isCloudflareEnabled: Bool = false,
         isQuad9Enabled: Bool = false,
         activeCustomDNSID: String? = nil,
         timestamp: Date = Date(),
         isAdGuardEnabled: Bool? = false,
         activeGetFlixLocation: String? = nil) {
        self.id = id
        self.isCloudflareEnabled = isCloudflareEnabled
        self.isQuad9Enabled = isQuad9Enabled
        self.activeCustomDNSID = activeCustomDNSID
        self.timestamp = timestamp
        self.isAdGuardEnabled = isAdGuardEnabled
    }
}

extension CustomDNSServer {
    /// Returns all user-entered DNS entries, supporting comma-separated values per field.
    var dnsEntries: [String] {
        [primaryDNS, secondaryDNS, tertiaryDNS ?? "", quaternaryDNS ?? ""]
            .flatMap { entry in
                entry
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
            .filter { !$0.isEmpty }
    }
}
