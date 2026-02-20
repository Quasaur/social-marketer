import Foundation
import Darwin

/// Manages the Social Effects API server process lifecycle
/// Handles starting, monitoring, and stopping the external Swift process
class SocialEffectsProcessManager {
    static let shared = SocialEffectsProcessManager()
    
    private var process: Process?
    private let socialEffectsPath = "/Users/quasaur/Developer/social-effects"
    private let serverPort: UInt16 = 5390
    private var isRunning = false
    
    private init() {}
    
    /// Starts the Social Effects API server
    /// - Returns: True if server started successfully
    func startServer() async throws -> Bool {
        guard !isRunning else {
            // Already running, verify it's healthy
            return await checkHealth()
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = ["run", "SocialEffects", "api-server", String(serverPort)]
        process.currentDirectoryURL = URL(fileURLWithPath: socialEffectsPath)
        
        // Redirect output to avoid blocking
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        self.process = process
        
        // Wait a moment for server to start
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Verify server is responding
        let healthy = await checkHealth()
        isRunning = healthy
        
        if healthy {
            print("✅ Social Effects API server started on port \(serverPort)")
        } else {
            print("❌ Failed to start Social Effects server")
            process.terminate()
            self.process = nil
        }
        
        return healthy
    }
    
    /// Checks if the Social Effects server is healthy
    /// - Returns: True if server responds to health check
    func checkHealth() async -> Bool {
        guard let url = URL(string: "http://localhost:\(serverPort)/health") else {
            return false
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               json["status"] == "ok" {
                return true
            }
        } catch {
            return false
        }
        
        return false
    }
    
    /// Shuts down the Social Effects API server gracefully
    func shutdownServer() async {
        guard isRunning else { return }
        
        // Try graceful shutdown via API first
        if let url = URL(string: "http://localhost:\(serverPort)/shutdown") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   httpResponse.statusCode == 200 {
                    print("✅ Social Effects server shutdown gracefully")
                }
            } catch {
                print("⚠️ Graceful shutdown failed, forcing termination")
            }
        }
        
        // Force terminate if still running
        if let process = process, process.isRunning {
            process.terminate()
            
            // Wait for termination
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            if process.isRunning {
                // Force kill using POSIX signal
                kill(process.processIdentifier, SIGKILL)
            }
        }
        
        isRunning = false
        process = nil
        print("✅ Social Effects server stopped")
    }
    
    /// Returns whether the server is currently running
    var serverIsRunning: Bool {
        get async {
            if !isRunning { return false }
            return await checkHealth()
        }
    }
}
