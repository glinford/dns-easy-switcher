//
//  DNSSpeedTester.swift
//  DNS Easy Switcher
//
//  Created by Gregory LINFORD on 25/02/2025.
//

import Foundation
import SwiftData

class DNSSpeedTester {
    static let shared = DNSSpeedTester()
    
    // Result struct to store ping results
    struct PingResult: Identifiable {
        let id = UUID()
        let dnsName: String
        let server: String
        let responseTime: Double // in milliseconds
        let isSuccess: Bool
        let isCustom: Bool
        let customID: String?
        
        init(dnsName: String, server: String, responseTime: Double, isSuccess: Bool, isCustom: Bool = false, customID: String? = nil) {
            self.dnsName = dnsName
            self.server = server
            self.responseTime = responseTime
            self.isSuccess = isSuccess
            self.isCustom = isCustom
            self.customID = customID
        }
    }
    
    // Track running tasks to ensure proper cleanup
    private var runningTasks: [Process] = []
    private var isCurrentlyTesting = false
    
    // Perform ping test for all DNS servers including custom ones
    func testAllDNS(customServers: [CustomDNSServer], completion: @escaping ([PingResult]) -> Void) {
        // Safety check to prevent multiple simultaneous tests
        guard !isCurrentlyTesting else {
            completion([])
            return
        }
        
        isCurrentlyTesting = true
        runningTasks = []
        
        let dnsManager = DNSManager.shared
        
        var allDNSToTest: [(String, String, Bool, String?)] = [
            ("Cloudflare", dnsManager.cloudflareServers[0], false, nil),
            ("Quad9", dnsManager.quad9Servers[0], false, nil),
            ("AdGuard", dnsManager.adguardServers[0], false, nil)
        ]
        
        // Add all Getflix servers
        let getflixServers = dnsManager.getflixServers.sorted(by: { $0.key < $1.key })
        allDNSToTest.append(contentsOf: getflixServers.map { ("Getflix: \($0.key)", $0.value, false, nil) })
        
        // Add custom DNS servers
        allDNSToTest.append(contentsOf: customServers.map {
            ($0.name, $0.primaryDNS, true, $0.id)
        })
        
        // Use serial queue to avoid overwhelming the system
        let queue = DispatchQueue(label: "com.glinford.DNSSpeedTest", qos: .userInitiated)
        let resultsQueue = DispatchQueue(label: "com.glinford.DNSSpeedTestResults", attributes: .concurrent)
        let resultsLock = NSLock()
        var results: [PingResult] = []
        let group = DispatchGroup()
        
        // Create a semaphore to limit concurrent operations
        let semaphore = DispatchSemaphore(value: 5) // Allow 5 concurrent pings
        
        for (index, (name, server, isCustom, customID)) in allDNSToTest.enumerated() {
            group.enter()
            
            // Add a small delay between tests to avoid overwhelming the system
            queue.asyncAfter(deadline: .now() + Double(index) * 0.05) { [weak self] in
                guard let self = self else {
                    semaphore.signal()
                    group.leave()
                    return
                }
                
                semaphore.wait() // Wait for a slot to become available
                
                self.pingServer(server: server) { responseTime, isSuccess in
                    resultsQueue.async {
                        resultsLock.lock()
                        let result = PingResult(
                            dnsName: name,
                            server: server,
                            responseTime: responseTime,
                            isSuccess: isSuccess,
                            isCustom: isCustom,
                            customID: customID
                        )
                        results.append(result)
                        resultsLock.unlock()
                        
                        semaphore.signal() // Release the slot
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Clean up any remaining processes
            for task in self.runningTasks {
                if task.isRunning {
                    task.terminate()
                }
            }
            self.runningTasks = []
            self.isCurrentlyTesting = false
            
            // Sort results by response time
            let sortedResults = results.sorted { $0.responseTime < $1.responseTime }
            completion(sortedResults)
        }
    }
    
    // Cancel any ongoing tests
    func cancelTests() {
        for task in runningTasks {
            if task.isRunning {
                task.terminate()
            }
        }
        runningTasks = []
        isCurrentlyTesting = false
    }
    
    // Clean up when app is terminating
    func cleanup() {
        cancelTests()
    }
    
    // Measure ping time to a DNS server with safer implementation
    private func pingServer(server: String, completion: @escaping (Double, Bool) -> Void) {
        let task = Process()
        task.launchPath = "/sbin/ping"
        task.arguments = ["-c", "2", "-t", "1", server] // 2 pings with 1-second timeout (reduced for speed)
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        // Keep track of task for cleanup
        runningTasks.append(task)
        
        // Set up termination handler before running
        task.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            
            // Remove this task from our tracking list
            if let index = self.runningTasks.firstIndex(where: { $0 === process }) {
                self.runningTasks.remove(at: index)
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse ping results
            if process.terminationStatus == 0 && output.contains("min/avg/max") {
                // More robust parsing approach
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("min/avg/max") {
                        let parts = line.components(separatedBy: "=")
                        if parts.count >= 2 {
                            let stats = parts[1].trimmingCharacters(in: .whitespaces)
                            let values = stats.components(separatedBy: "/")
                            if values.count >= 2 {
                                if let avgTime = Double(values[1].trimmingCharacters(in: .whitespaces)) {
                                    completion(avgTime, true)
                                    return
                                }
                            }
                        }
                    }
                }
                // If we get here, parsing failed
                completion(999, false)
            } else {
                completion(999, false) // Ping failed
            }
        }
        
        do {
            try task.run()
        } catch {
            // Remove this task from our tracking list if it failed to start
            if let index = runningTasks.firstIndex(where: { $0 === task }) {
                runningTasks.remove(at: index)
            }
            
            completion(999, false) // Process failed to start
        }
    }
    
    // Deinitializer to clean up resources
    deinit {
        cleanup()
    }
}
