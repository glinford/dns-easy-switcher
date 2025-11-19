//
//  DNSSettings.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import SwiftData

struct PredefinedDNSServer: Identifiable, Hashable, Codable {
    var id: String
    let name: String
    let servers: [String]
}

@Model
final class CustomDNSServer: Identifiable {
    var id: String
    var name: String
    var servers: [String]
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         name: String,
         servers: [String],
         timestamp: Date = Date()) {
        self.id = id
        self.name = name
        self.servers = servers
        self.timestamp = timestamp
    }
}

@Model
final class DNSSettings {
    @Attribute(.unique) var id: String
    var activeServerID: String?
    var timestamp: Date
    
    init(id: String = UUID().uuidString,
         activeServerID: String? = nil,
         timestamp: Date = Date()) {
        self.id = id
        self.activeServerID = activeServerID
        self.timestamp = timestamp
    }
}
