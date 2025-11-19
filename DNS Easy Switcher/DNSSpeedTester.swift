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
        let id: String // Corresponds to PredefinedDNSServer.id or CustomDNSServer.id
        let dnsName: String
        let responseTime: Double // in milliseconds
        let isSuccess: Bool
    }
    
    // Thread-safety for task management
    private var runningTasks: [Process] = []
    private let tasksLock = NSLock()
    private var isCurrentlyTesting = false
    
    // Perform ping test for all DNS servers including custom ones
    func testAllDNS(predefinedServers: [PredefinedDNSServer], customServers: [CustomDNSServer], completion: @escaping ([PingResult]) -> Void) {
        guard !isCurrentlyTesting else {
            completion([])
            return
        }
        
        isCurrentlyTesting = true
        
        tasksLock.lock()
        runningTasks = []
        tasksLock.unlock()
        
        var allDNSToTest: [(id: String, name: String, serverToPing: String)] = []
        
        // Add predefined and Getflix servers
        allDNSToTest.append(contentsOf: predefinedServers.map {
            (id: $0.id, name: $0.name, serverToPing: $0.servers.first ?? "")
        })
        
        // Add custom DNS servers
        allDNSToTest.append(contentsOf: customServers.map {
            (id: $0.id, name: $0.name, serverToPing: $0.servers.first ?? "")
        })
        
        // Filter out any servers with an empty address to ping
        allDNSToTest = allDNSToTest.filter { !$0.serverToPing.isEmpty }
        
        let queue = DispatchQueue(label: "com.glinford.DNSSpeedTest", qos: .userInitiated)
        let resultsQueue = DispatchQueue(label: "com.glinford.DNSSpeedTestResults", attributes: .concurrent)
        let resultsLock = NSLock()
        var results: [PingResult] = []
        let group = DispatchGroup()
        
        let semaphore = DispatchSemaphore(value: 5) // Allow 5 concurrent pings
        
        for (index, serverInfo) in allDNSToTest.enumerated() {
            group.enter()
            
            queue.asyncAfter(deadline: .now() + Double(index) * 0.05) { [weak self] in
                guard let self = self else {
                    semaphore.signal()
                    group.leave()
                    return
                }
                
                semaphore.wait()
                
                self.pingServer(server: serverInfo.serverToPing) { responseTime, isSuccess in
                    resultsQueue.async {
                        resultsLock.lock()
                        let result = PingResult(
                            id: serverInfo.id,
                            dnsName: serverInfo.name,
                            responseTime: responseTime,
                            isSuccess: isSuccess
                        )
                        results.append(result)
                        resultsLock.unlock()
                        
                        semaphore.signal()
                        group.leave()
                    }
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            self.cleanupRunningTasks()
            self.isCurrentlyTesting = false
            
            let sortedResults = results.sorted { $0.responseTime < $1.responseTime }
            completion(sortedResults)
        }
    }
    
    private func cleanupRunningTasks() {
        tasksLock.lock()
        for task in runningTasks {
            if task.isRunning {
                task.terminate()
            }
        }
        runningTasks = []
        tasksLock.unlock()
    }
    
    func cancelTests() {
        cleanupRunningTasks()
        isCurrentlyTesting = false
    }
    
    deinit {
        cancelTests()
    }
    
    private func pingServer(server: String, completion: @escaping (Double, Bool) -> Void) {
        let task = Process()
        task.launchPath = "/sbin/ping"
        task.arguments = ["-c", "2", "-t", "1", server]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        tasksLock.lock()
        runningTasks.append(task)
        tasksLock.unlock()
        
        task.terminationHandler = { [weak self] process in
            guard let self = self else { return }
            
            self.tasksLock.lock()
            if let index = self.runningTasks.firstIndex(where: { $0 === process }) {
                self.runningTasks.remove(at: index)
            }
            self.tasksLock.unlock()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0, let avgTime = self.parsePingOutput(output) {
                completion(avgTime, true)
            } else {
                completion(999, false)
            }
        }
        
        do {
            try task.run()
        } catch {
            tasksLock.lock()
            if let index = runningTasks.firstIndex(where: { $0 === task }) {
                runningTasks.remove(at: index)
            }
            tasksLock.unlock()
            completion(999, false)
        }
    }
    
    private func parsePingOutput(_ output: String) -> Double? {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("min/avg/max") {
                let parts = line.components(separatedBy: "=")
                if parts.count >= 2 {
                    let stats = parts[1].trimmingCharacters(in: .whitespaces)
                    let values = stats.components(separatedBy: "/")
                    if values.count >= 2, let avgTime = Double(values[1].trimmingCharacters(in: .whitespaces)) {
                        return avgTime
                    }
                }
            }
        }
        return nil
    }
}
