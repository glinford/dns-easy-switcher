//
//  DNSManager.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 23/02/2025.
//

import Foundation
import AppKit
import os
import LocalAuthentication

class DNSManager {
    static let shared = DNSManager()
    private let logger = Logger(subsystem: "com.linfordsoftware.dnseasyswitcher", category: "DNSManager")

    static let predefinedServers: [PredefinedDNSServer] = [
        PredefinedDNSServer(id: "cloudflare", name: "Cloudflare DNS", servers: [
            "1.1.1.1",
            "1.0.0.1",
            "2606:4700:4700::1111",
            "2606:4700:4700::1001"
        ]),
        PredefinedDNSServer(id: "quad9", name: "Quad9 DNS", servers: [
            "9.9.9.9",
            "149.112.112.112",
            "2620:fe::fe",
            "2620:fe::9"
        ]),
        PredefinedDNSServer(id: "adguard", name: "AdGuard DNS", servers: [
            "94.140.14.14",
            "94.140.15.15",
            "2a10:50c0::ad1:ff",
            "2a10:50c0::ad2:ff"
        ])
    ]

    static let getflixServers: [PredefinedDNSServer] = [
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
    ].map { PredefinedDNSServer(id: "getflix-\($0.key)", name: $0.key, servers: [$0.value]) }
     .sorted { $0.name < $1.name }

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
            logger.error("Error getting network services: \(String(describing: error), privacy: .public)")
        }
        return []
    }

    private func findActiveServices() -> [String] {
        let services = getNetworkServices()
        let deviceMap = getServiceDeviceMap()

        var active: [String] = []
        for service in services {
            if serviceHasIPv4(service) {
                active.append(service)
                continue
            }

            if let device = deviceMap[service], isDeviceActive(device) {
                active.append(service)
            }
        }

        let chosen = active.isEmpty ? [services.first].compactMap { $0 } : active
        logger.info("Active services: \(chosen.joined(separator: ", "), privacy: .public)")
        return chosen
    }

    private func getServiceDeviceMap() -> [String: String] {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-listnetworkserviceorder"]

        let pipe = Pipe()
        task.standardOutput = pipe

        var map: [String: String] = [:]
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                var currentService: String?
                for rawLine in output.components(separatedBy: .newlines) {
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    if line.hasPrefix("(") {
                        if let range = line.range(of: ") ") {
                            let name = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                            currentService = name
                        }
                    } else if line.contains("Device:") {
                        let parts = line.components(separatedBy: "Device:")
                        if parts.count >= 2 {
                            var dev = parts[1].trimmingCharacters(in: .whitespaces)
                            if let endParen = dev.firstIndex(of: ")") {
                                dev = String(dev[..<endParen])
                            }
                            if let svc = currentService {
                                map[svc] = dev
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to get service-device map: \(String(describing: error), privacy: .public)")
        }
        return map
    }

    private func serviceHasIPv4(_ service: String) -> Bool {
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getinfo", service]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for rawLine in output.components(separatedBy: .newlines) {
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    if line.lowercased().hasPrefix("ip address:") {
                        let value = line.replacingOccurrences(of: "IP address:", with: "").trimmingCharacters(in: .whitespaces)
                        if !value.isEmpty && value.lowercased() != "none" {
                            return true
                        }
                    }
                }
            }
        } catch {
            logger.error("Failed to get info for service \(service, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        return false
    }

    private func isDeviceActive(_ device: String) -> Bool {
        let task = Process()
        task.launchPath = "/sbin/ifconfig"
        task.arguments = [device]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("status: active") { return true }
                let hasInet4 = output.contains(" inet ") && !output.contains(" inet 127.0.0.1")
                let hasInet6 = output.contains(" inet6 ") && !output.contains(" inet6 fe80:")
                return hasInet4 || hasInet6
            }
        } catch {
            logger.error("Failed to read interface \(device, privacy: .public): \(String(describing: error), privacy: .public)")
        }
        return false
    }


    // Execute a shell command with administrator privileges using AppleScript
    private func executeAdminScript(command: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = """
            do shell script "\(command)" with administrator privileges with prompt "DNS Easy Switcher needs to modify network settings"
            """

            var errorDict: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&errorDict)
                if errorDict == nil {
                    DispatchQueue.main.async { completion(true) }
                } else {
                    self.logger.error("AppleScript error: \(String(describing: errorDict), privacy: .public)")
                    DispatchQueue.main.async { completion(false) }
                }
            } else {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }


    func setDNS(servers: [String], completion: @escaping (Bool) -> Void) {
        let services = findActiveServices()
        guard !services.isEmpty else {
            completion(false)
            return
        }

        // Check if any server contains an IPv4 address with port specification
        let hasPort = servers.contains { $0.contains(".") && $0.contains(":") }

        // If no custom ports are specified, use the standard network setup method
        if !hasPort {
            setStandardDNS(services: services, servers: servers, completion: completion)
            return
        }

        // For DNS servers with custom ports, we need to modify the resolver configuration
        let resolverContent = createResolverContent(servers)

        let createDirCmd = "/bin/mkdir -p /etc/resolver"
        executeAdminScript(command: createDirCmd) { [self] dirSuccess in
            guard dirSuccess else {
                logger.error("Failed to create resolver directory")
                completion(false)
                return
            }

            // Now write the resolver content
            let writeFileCmd = """
            /usr/bin/tee /etc/resolver/custom > /dev/null <<'EOF'
            \(resolverContent)
            EOF
            """
            self.executeAdminScript(command: writeFileCmd) { [self] fileSuccess in
                guard fileSuccess else {
                    logger.error("Failed to write resolver configuration")
                    completion(false)
                    return
                }

                // Set permissions
                let permCmd = "/bin/chmod 644 /etc/resolver/custom"
                self.executeAdminScript(command: permCmd) { [self] permSuccess in
                    if !permSuccess {
                        logger.error("Failed to set resolver file permissions")
                        completion(false)
                        return
                    }

                    // Also set standard DNS servers to ensure proper resolution
                    let standardServers = self.formatDNSWithoutPorts(servers)
                    self.setStandardDNS(services: services, servers: standardServers, completion: completion)
                }
            }
        }
    }

    private func createResolverContent(_ servers: [String]) -> String {
        var resolverContent = "# Custom DNS configuration with port\n"

        for server in servers {
            if server.contains(":") {
                let components = server.components(separatedBy: ":")
                if components.count == 2, let port = Int(components[1]) {
                    resolverContent += "nameserver \(components[0])\n"
                    resolverContent += "port \(port)\n"
                }
            } else {
                resolverContent += "nameserver \(server)\n"
            }
        }

        logger.info("Custom resolver content:\n\(resolverContent, privacy: .public)")
        return resolverContent
    }

    func disableDNS(completion: @escaping (Bool) -> Void) {
        let services = findActiveServices()
        guard !services.isEmpty else {
            completion(false)
            return
        }

        // Remove any custom resolver configuration
        let removeResolverCmd = "/bin/rm -f /etc/resolver/custom"

        executeAdminScript(command: removeResolverCmd) { [self] _ in
            // Continue with normal DNS reset regardless of resolver removal success
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true

        for service in services {
            dispatchGroup.enter()

                let command = "/usr/sbin/networksetup -setdnsservers '\(service)' empty"
                logger.info("Resetting DNS for service \(service, privacy: .public)")

                self.executeAdminScript(command: command) { [self] success in
                    if !success {
                        allSucceeded = false
                        logger.error("DNS reset failed for service \(service, privacy: .public)")
                    } else {
                        logger.info("DNS reset for service \(service, privacy: .public)")
                    }
                    dispatchGroup.leave()
                }
            }

            dispatchGroup.notify(queue: .main) {
                completion(allSucceeded)
            }
        }
    }

    // Helper method to get DNS addresses without port specifications
    private func formatDNSWithoutPorts(_ servers: [String]) -> [String] {
        var serversWithoutPort: [String] = []

        for server in servers {
            // Extract IP address without port (only for IPv4 addresses)
            let components = server.split(separator: ":", omittingEmptySubsequences: false)
            if components.count == 2 {
                serversWithoutPort.append(String(components[0]))
            } else {
                serversWithoutPort.append(server)
            }
        }

        return serversWithoutPort
    }

    // Helper method to set standard DNS settings
    private func setStandardDNS(services: [String], servers: [String], completion: @escaping (Bool) -> Void) {
        let dispatchGroup = DispatchGroup()
        var allSucceeded = true

        for service in services {
            dispatchGroup.enter()

            let dnsArgs = servers.joined(separator: " ")
            let dnsCommand = "/usr/sbin/networksetup -setdnsservers '\(service)' \(dnsArgs)"
            logger.info("Setting DNS for service \(service, privacy: .public) to \(dnsArgs, privacy: .public)")

            executeAdminScript(command: dnsCommand) { [self] success in
                if !success {
                        allSucceeded = false
                        logger.error("DNS apply failed for service \(service, privacy: .public)")
                    } else {
                        logger.info("DNS applied for service \(service, privacy: .public)")
                    }
                    dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(allSucceeded)
        }
    }


    func clearDNSCache(completion: @escaping (Bool) -> Void) {
        let flushCommand = "dscacheutil -flushcache"
        logger.info("Flushing DNS cache")

        executeAdminScript(command: flushCommand) { success in
            if success {
                let restartCommand = "killall -HUP mDNSResponder 2>/dev/null || killall -HUP mdnsresponder 2>/dev/null || true"

                self.executeAdminScript(command: restartCommand) { _ in
                    self.logger.info("DNS cache flushed and mDNSResponder restarted")
                    completion(success)
                }
            } else {
                self.logger.error("Failed to flush DNS cache")
                completion(false)
            }
        }
    }
}
