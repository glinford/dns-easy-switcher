//
//  DNSManager.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import AppKit

class DNSManager {
    static let shared = DNSManager()
    
    let cloudflareServers = [
        "1.1.1.1",           // IPv4 Primary
        "1.0.0.1",           // IPv4 Secondary
        "2606:4700:4700::1111",  // IPv6 Primary
        "2606:4700:4700::1001"   // IPv6 Secondary
    ]
    
    let quad9Servers = [
        "9.9.9.9",              // IPv4 Primary
        "149.112.112.112",      // IPv4 Secondary
        "2620:fe::fe",          // IPv6 Primary
        "2620:fe::9"            // IPv6 Secondary
    ]
    
    let adguardServers = [
        "94.140.14.14",       // IPv4 Primary
        "94.140.15.15",       // IPv4 Secondary
        "2a10:50c0::ad1:ff",  // IPv6 Primary
        "2a10:50c0::ad2:ff"   // IPv6 Secondary
    ]
    
    let getflixServers: [String: String] = [
        "Australia — Melbourne": "118.127.62.178",
        "Australia — Perth": "45.248.78.99",
        "Australia — Sydney 1": "54.252.183.4",
        "Australia — Sydney 2": "54.252.183.5",
        "Brazil — São Paulo": "54.94.175.250",
        "Canada — Toronto": "169.53.182.124",
        "Denmark — Copenhagen": "82.103.129.240",
        "Germany — Frankfurt": "54.93.169.181",
        "Great Britain — London": "212.71.249.225",
        "Hong Kong": "119.9.73.44",
        "India — Mumbai": "103.13.112.251",
        "Ireland — Dublin": "54.72.70.84",
        "Italy — Milan": "95.141.39.238",
        "Japan — Tokyo": "172.104.90.123",
        "Netherlands — Amsterdam": "46.166.189.67",
        "New Zealand — Auckland 1": "120.138.27.84",
        "New Zealand — Auckland 2": "120.138.22.174",
        "Singapore": "54.251.190.247",
        "South Africa — Johannesburg": "102.130.116.140",
        "Spain — Madrid": "185.93.3.168",
        "Sweden — Stockholm": "46.246.29.68",
        "Turkey — Istanbul": "212.68.53.190",
        "United States — Dallas (Central)": "169.55.51.86",
        "United States — Oregon (West)": "54.187.61.200",
        "United States — Virginia (East)": "54.164.176.2"
    ]
    
    private func getNetworkServices() -> [String] {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listallnetworkservices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let services = String(data: data, encoding: .utf8) {
                return services.components(separatedBy: .newlines)
                    .dropFirst() // Drop the header line
                    .filter { !$0.isEmpty && !$0.hasPrefix("*") } // Remove empty lines and disabled services
            }
        } catch {
            print("Error getting network services: \(error)")
        }
        return []
    }
    
    private func findActiveService() -> String? {
        let services = getNetworkServices()
        return services.first(where: { $0.lowercased().contains("wi-fi") })
            ?? services.first(where: { $0.lowercased().contains("ethernet") })
            ?? services.first
    }
    
    private func executePrivilegedCommand(arguments: [String]) -> Bool {
        guard let service = findActiveService() else { return false }
        
        // Properly escape the arguments for AppleScript
        let escapedArgs = arguments.map { arg in
            return "\\\"" + arg.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\\\""
        }.joined(separator: " ")
        
        let scriptText = """
        do shell script "/usr/sbin/networksetup \(escapedArgs)" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptText) {
            if scriptObject.executeAndReturnError(&error) != nil {
                // Also set IPv6 DNS if we successfully set IPv4
                if arguments[0] == "-setdnsservers" {
                    _ = executeIPv6Command(service: service, isDisabling: arguments.contains("empty"))
                }
                return true
            } else if let error = error {
                print("Error executing privileged command: \(error)")
            }
        }
        return false
    }
    
    private func executeIPv6Command(service: String, isDisabling: Bool) -> Bool {
        let scriptText = """
        do shell script "/usr/sbin/networksetup -setv6off '\(service)'; /usr/sbin/networksetup -setv6automatic '\(service)'" with administrator privileges
        """
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: scriptText) {
            if scriptObject.executeAndReturnError(&error) != nil {
                return true
            } else if let error = error {
                print("Error executing IPv6 command: \(error)")
            }
        }
        return false
    }
    
    func setPredefinedDNS(dnsServers: [String], completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let service = self.findActiveService() else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let success = self.executePrivilegedCommand(arguments: ["-setdnsservers", service] + dnsServers)
            DispatchQueue.main.async { completion(success) }
        }
    }
    
    func setCustomDNS(primary: String, secondary: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let service = self.findActiveService() else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            var servers = [primary]
            if !secondary.isEmpty {
                servers.append(secondary)
            }
            
            let success = self.executePrivilegedCommand(arguments: ["-setdnsservers", service] + servers)
            DispatchQueue.main.async { completion(success) }
        }
    }
    
    func disableDNS(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let service = self.findActiveService() else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let success = self.executePrivilegedCommand(arguments: ["-setdnsservers", service, "empty"])
            DispatchQueue.main.async { completion(success) }
        }
    }
}
