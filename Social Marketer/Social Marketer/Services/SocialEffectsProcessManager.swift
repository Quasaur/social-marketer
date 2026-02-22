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
        
        // Check if a server is already running on the port (from a previous launch)
        if await checkHealth() {
            print("✅ Social Effects server already running on port \(serverPort)")
            isRunning = true
            return true
        }
        
        // Check if binary exists, fall back to swift run if not
        let binaryPath = "\(socialEffectsPath)/.build/debug/SocialEffects"
        let useBinary = FileManager.default.fileExists(atPath: binaryPath)
        
        let process = Process()
        if useBinary {
            // Use pre-built binary (faster)
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments = ["api-server", String(serverPort)]
            print("🚀 Starting Social Effects from pre-built binary...")
        } else {
            // Fall back to swift run (slower, builds first)
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = ["run", "SocialEffects", "api-server", String(serverPort)]
            process.currentDirectoryURL = URL(fileURLWithPath: socialEffectsPath)
            print("🚀 Starting Social Effects via swift run (building if needed)...")
        }
        
        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Start process
        try process.run()
        self.process = process
        
        // Wait for server to start with progressive retry
        var healthy = false
        for attempt in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            healthy = await checkHealth()
            if healthy { break }
            if Log.isDebugMode {
                Log.debug("Waiting for server... (attempt \(attempt)/10)", category: "SocialEffects")
            }
        }
        
        isRunning = healthy
        
        if healthy {
            print("✅ Social Effects API server started on port \(serverPort)")
        } else {
            // Read error output for debugging
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            let stdoutData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let stdoutOutput = String(data: stdoutData, encoding: .utf8) ?? ""
            
            print("❌ Failed to start Social Effects server")
            print("   stderr: \(errorOutput)")
            print("   stdout: \(stdoutOutput)")
            
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
            // First check if the process is still alive
            if let process = process {
                if !process.isRunning {
                    if Log.isDebugMode {
                        Log.debug("Social Effects process terminated unexpectedly", category: "SocialEffects")
                    }
                    isRunning = false
                    self.process = nil
                    return false
                }
            } else if isRunning {
                // Process is nil but flag says running - inconsistent state
                if Log.isDebugMode {
                    Log.debug("Social Effects process nil but flag says running", category: "SocialEffects")
                }
                isRunning = false
                return false
            }
            
            // Process exists and is running, check health
            if !isRunning { return false }
            let healthy = await checkHealth()
            if !healthy && Log.isDebugMode {
                Log.debug("Social Effects process running but not responding to health check", category: "SocialEffects")
            }
            return healthy
        }
    }
}
