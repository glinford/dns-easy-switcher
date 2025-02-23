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
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         name: String,
         primaryDNS: String,
         secondaryDNS: String,
         timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.primaryDNS = primaryDNS
        self.secondaryDNS = secondaryDNS
        self.timestamp = timestamp
    }
}

@Model
final class DNSSettings {
    @Attribute(.unique) var id: String
    var isCloudflareEnabled: Bool
    var isQuad9Enabled: Bool
    var isAdGuardEnabled: Bool
    var activeCustomDNSID: String?
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         isCloudflareEnabled: Bool = false,
         isQuad9Enabled: Bool = false,
         isAdGuardEnabled: Bool = false,
         activeCustomDNSID: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.isCloudflareEnabled = isCloudflareEnabled
        self.isQuad9Enabled = isQuad9Enabled
        self.isAdGuardEnabled = isAdGuardEnabled
        self.activeCustomDNSID = activeCustomDNSID
        self.timestamp = timestamp
    }
}
