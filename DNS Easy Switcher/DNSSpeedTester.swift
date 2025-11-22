import Foundation
import SwiftData

actor DNSSpeedTester {
    static let shared = DNSSpeedTester()

    // Result struct to store ping results
    struct PingResult: Identifiable, Sendable {
        let id: String // Corresponds to PredefinedDNSServer.id or CustomDNSServer.id
        let dnsName: String
        let responseTime: Double // in milliseconds
        let isSuccess: Bool
    }

    private var isCurrentlyTesting = false
    private var currentTask: Task<Void, Never>?

    // Perform ping test for all DNS servers including custom ones
    func testAllDNS(predefinedServers: [PredefinedDNSServer], customServers: [CustomDNSServer], completion: @escaping ([PingResult]) -> Void) {
        guard !isCurrentlyTesting else {
            completion([])
            return
        }

        isCurrentlyTesting = true
        
        currentTask = Task {
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

            var results: [PingResult] = []
            
            await withTaskGroup(of: PingResult.self) { group in
                // Limit concurrency to 5
                let maxConcurrent = 5
                var activeCount = 0
                
                for serverInfo in allDNSToTest {
                    if activeCount >= maxConcurrent {
                        if let result = await group.next() {
                            results.append(result)
                            activeCount -= 1
                        }
                    }
                    
                    group.addTask {
                        let components = serverInfo.serverToPing.split(separator: ":", omittingEmptySubsequences: false)
                        let serverToPing = components.count == 2 ? String(components[0]) : serverInfo.serverToPing
                        
                        let (time, success) = await self.pingServer(server: serverToPing)
                        return PingResult(
                            id: serverInfo.id,
                            dnsName: serverInfo.name,
                            responseTime: time,
                            isSuccess: success
                        )
                    }
                    activeCount += 1
                }
                
                // Collect remaining results
                for await result in group {
                    results.append(result)
                }
            }

            let sortedResults = results.sorted { $0.responseTime < $1.responseTime }
            
            isCurrentlyTesting = false
            currentTask = nil
            
            await MainActor.run {
                completion(sortedResults)
            }
        }
    }

    func cancelTests() {
        currentTask?.cancel()
        isCurrentlyTesting = false
        currentTask = nil
    }

    private func pingServer(server: String) async -> (Double, Bool) {
        return await withCheckedContinuation { continuation in
            let task = Process()
            task.launchPath = "/sbin/ping"
            task.arguments = ["-c", "2", "-t", "1", server]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe

            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus == 0, let avgTime = self.parsePingOutput(output) {
                    continuation.resume(returning: (avgTime, true))
                } else {
                    continuation.resume(returning: (999, false))
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(returning: (999, false))
            }
        }
    }

    nonisolated private func parsePingOutput(_ output: String) -> Double? {
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
