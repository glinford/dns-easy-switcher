//
//  DNSManager.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import AppKit
import LocalAuthentication

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
    
    private func findActiveServices() -> [String] {
        let services = getNetworkServices()
        let activeServices = services.filter {
            $0.lowercased().contains("wi-fi") || $0.lowercased().contains("ethernet")
        }
        return activeServices.isEmpty ? [services.first].compactMap { $0 } : activeServices
    }
    
    private func executeWithAuthentication(command: String, completion: @escaping (Bool) -> Void) {
            let context = LAContext()
            context.localizedReason = "DNS Easy Switcher needs to modify network settings"
            
            var error: NSError?
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "DNS Easy Switcher needs to modify network settings") { success, error in
                    if success {
                        DispatchQueue.global(qos: .userInitiated).async {
                            let task = Process()
                            task.launchPath = "/bin/bash"
                            task.arguments = ["-c", command]
                            
                            let pipe = Pipe()
                            task.standardOutput = pipe
                            
                            do {
                                try task.run()
                                task.waitUntilExit()
                                
                                let success = task.terminationStatus == 0
                                DispatchQueue.main.async { completion(success) }
                            } catch {
                                print("Failed to execute command: \(error)")
                                DispatchQueue.main.async { completion(false) }
                            }
                        }
                    } else {
                        print("Authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                        DispatchQueue.main.async { completion(false) }
                    }
                }
            } else {
                // Fall back to AppleScript for admin privileges
                print("Local Authentication not available: \(error?.localizedDescription ?? "Unknown error")")
                
                DispatchQueue.global(qos: .userInitiated).async {
                    let script = """
                    do shell script "\(command)" with administrator privileges
                    """
                    
                    var scriptError: NSDictionary?
                    if let scriptObject = NSAppleScript(source: script) {
                        if scriptObject.executeAndReturnError(&scriptError) != nil {
                            DispatchQueue.main.async { completion(true) }
                        } else {
                            print("AppleScript error: \(scriptError ?? ["error": "Unknown error"] as NSDictionary)")
                            DispatchQueue.main.async { completion(false) }
                        }
                    } else {
                        DispatchQueue.main.async { completion(false) }
                    }
                }
            }
        }
    
    func setPredefinedDNS(dnsServers: [String], completion: @escaping (Bool) -> Void) {
        let services = findActiveServices()
        guard !services.isEmpty else {
            completion(false)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true
        
        for service in services {
            dispatchGroup.enter()
            
            let dnsArgs = dnsServers.joined(separator: " ")
            let dnsCommand = "/usr/sbin/networksetup -setdnsservers '\(service)' \(dnsArgs)"
            let ipv6Command = "/usr/sbin/networksetup -setv6off '\(service)'; /usr/sbin/networksetup -setv6automatic '\(service)'"
            let fullCommand = "\(dnsCommand); \(ipv6Command)"
            
            executeWithAuthentication(command: fullCommand) { success in
                if !success {
                    allSucceeded = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allSucceeded)
        }
    }
        
    func setCustomDNS(primary: String, secondary: String, completion: @escaping (Bool) -> Void) {
        let services = findActiveServices()
        guard !services.isEmpty else {
            completion(false)
            return
        }
        
        // Format DNS servers with port if specified
        let formattedPrimary = formatDNSWithPort(primary)
        let formattedSecondary = secondary.isEmpty ? "" : formatDNSWithPort(secondary)
        
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true
        
        for service in services {
            dispatchGroup.enter()
            
            var servers = [formattedPrimary]
            if !formattedSecondary.isEmpty {
                servers.append(formattedSecondary)
            }
            
            let dnsArgs = servers.joined(separator: " ")
            let dnsCommand = "/usr/sbin/networksetup -setdnsservers '\(service)' \(dnsArgs)"
            let ipv6Command = "/usr/sbin/networksetup -setv6off '\(service)'; /usr/sbin/networksetup -setv6automatic '\(service)'"
            let fullCommand = "\(dnsCommand); \(ipv6Command)"
            
            executeWithAuthentication(command: fullCommand) { success in
                if !success {
                    allSucceeded = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allSucceeded)
        }
    }

    // Helper method to format DNS with port
    private func formatDNSWithPort(_ dnsServer: String) -> String {
        // If DNS server already includes a port (contains colon), return as is
        if dnsServer.contains(":") {
            return dnsServer
        }
        
        // If it's an IPv6 address that needs a port, format properly with square brackets
        if dnsServer.contains("::") || dnsServer.components(separatedBy: ":").count > 2 {
            // IPv6 addresses with ports need to be formatted as [address]:port
            return dnsServer
        }
        
        // Regular IPv4 address without port, return as is
        return dnsServer
    }
    
    func disableDNS(completion: @escaping (Bool) -> Void) {
        let services = findActiveServices()
        guard !services.isEmpty else {
            completion(false)
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true
        
        for service in services {
            dispatchGroup.enter()
            
            let command = "/usr/sbin/networksetup -setdnsservers '\(service)' empty"
            
            executeWithAuthentication(command: command) { success in
                if !success {
                    allSucceeded = false
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(allSucceeded)
        }
    }
    
    private func executePrivilegedCommand(arguments: [String]) -> Bool {
        let services = findActiveServices()
        guard !services.isEmpty else { return false }
        
        var success = true
        
        for service in services {
            // Properly escape the arguments for AppleScript
            let escapedArgs = arguments.map { arg in
                return "\\\"" + arg.replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"") + "\\\""
            }.joined(separator: " ")
            
            // Combine IPv4 and IPv6 commands in a single script if we're setting DNS
            let isSettingDNS = arguments[0] == "-setdnsservers"

            let commandScript: String
            if isSettingDNS {
                // Combine DNS and IPv6 commands with semicolons in a single admin privilege request
                let ipv6Script = "/usr/sbin/networksetup -setv6off '\(service)'; /usr/sbin/networksetup -setv6automatic '\(service)'"
                commandScript = """
                do shell script "/usr/sbin/networksetup \(escapedArgs); \(ipv6Script)" with administrator privileges with prompt "DNS Easy Switcher needs to modify network settings"
                """
            } else {
                // For other commands, keep as is
                commandScript = """
                do shell script "/usr/sbin/networksetup \(escapedArgs)" with administrator privileges with prompt "DNS Easy Switcher needs to modify network settings"
                """
            }
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: commandScript) {
                if scriptObject.executeAndReturnError(&error) == nil {
                    if let error = error {
                        print("Error executing privileged command: \(error)")
                        success = false
                    }
                }
            } else {
                success = false
            }
        }
        
        return success
    }
    
    func clearDNSCache(completion: @escaping (Bool) -> Void) {
        let flushCommand = "dscacheutil -flushcache"
        
        executeWithAuthentication(command: flushCommand) { success in
            if success {
                let restartCommand = "killall -HUP mDNSResponder 2>/dev/null || killall -HUP mdnsresponder 2>/dev/null || true"
                
                self.executeWithAuthentication(command: restartCommand) { _ in
                    completion(success)
                }
            } else {
                completion(false)
            }
        }
    }
}
