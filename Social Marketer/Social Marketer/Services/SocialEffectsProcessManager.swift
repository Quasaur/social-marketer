import Foundation
import Darwin

/// Manages the Social Effects API server process lifecycle
/// Handles starting, monitoring, and stopping the external Swift process
class SocialEffectsProcessManager {
    static let shared = SocialEffectsProcessManager()
    
    private var process: Process?
    
    /// Path to Social Effects installation (configurable via AppConfiguration)
    private var socialEffectsPath: String {
        let binaryPath = AppConfiguration.Paths.socialEffectsBinary
        let nsPath = binaryPath as NSString
        return (nsPath.deletingLastPathComponent as NSString).deletingLastPathComponent
    }
    
    /// Server port (extracted from Configuration URL)
    private var serverPort: UInt16 {
        guard let url = URL(string: AppConfiguration.URLs.socialEffects),
              let port = url.port else {
            return 5390  // Default fallback
        }
        return UInt16(port)
    }
    
    private var isRunning = false
    private var isExternalServer = false  // True if we detected an already-running server
    
    /// URLSession with short timeout for health checks
    private let healthCheckSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5  // 5 seconds for health check
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    /// Starts the Social Effects API server
    /// - Returns: True if server started successfully
    func startServer() async throws -> Bool {
        // First check if server is already responding (external or previously started)
        if await checkHealth() {
            print("✅ Social Effects server already running on port \(serverPort)")
            // Mark as external server - we don't own the process but should try to shut it down
            isExternalServer = true
            isRunning = true
            // Try to find the existing process
            // External server detected - we do not have process reference
            return true
        }
        
        // Reset external flag when starting our own instance
        isExternalServer = false
        
        // If we have a process reference but health check failed, the server is dead
        if let process = process, !process.isRunning {
            self.process = nil
            isRunning = false
        }
        
        // Check if binary exists, fall back to swift run if not
        let binaryPath = AppConfiguration.Paths.socialEffectsBinary
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
        let maxAttempts = Int(AppConfiguration.Timeouts.socialEffectsStartup / 0.5)
        for attempt in 1...maxAttempts {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            healthy = await checkHealth()
            if healthy { break }
            if Log.isDebugMode {
                Log.debug("Waiting for server... (attempt \(attempt)/10)", category: "SocialEffects")
            }
        }
        
        if healthy {
            isRunning = true
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
            isRunning = false
        }
        
        return healthy
    }
    
    /// Checks if the Social Effects server is healthy
    /// - Returns: True if server responds to health check within timeout
    func checkHealth() async -> Bool {
        guard let url = URL(string: AppConfiguration.URLs.socialEffectsHealth) else {
            return false
        }
        
        do {
            let (data, response) = try await healthCheckSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return false
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String],
               json["status"] == "ok" {
                return true
            }
        } catch {
            // Log the specific error for debugging
            if Log.isDebugMode {
                Log.debug("Health check failed: \(error.localizedDescription)", category: "SocialEffects")
            }
            return false
        }
        
        return false
    }
    
    /// Shuts down the Social Effects API server gracefully
    /// Always attempts shutdown if we have a process reference or if server is responding
    func shutdownServer() async {
        print("[SocialEffects] Starting shutdown sequence...")
        
        // Check if we have a process to terminate OR if server is responding to health check
        let hasProcess = (process != nil && process!.isRunning)
        let serverResponding = await checkHealth()
        
        print("[SocialEffects] State: hasProcess=\(hasProcess), serverResponding=\(serverResponding), isRunning=\(isRunning), isExternal=\(isExternalServer)")
        
        guard hasProcess || serverResponding || isRunning || isExternalServer else {
            print("[SocialEffects] ℹ️ Server not running, nothing to shut down")
            return
        }
        
        // Always try the API shutdown if we think the server might be running
        // This handles both our managed process and external servers
        print("[SocialEffects] Attempting shutdown via API...")
        if let url = URL(string: "\(AppConfiguration.URLs.socialEffects)/shutdown") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5  // 5 second timeout for shutdown
            
            do {
                let (_, response) = try await healthCheckSession.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        print("[SocialEffects] ✅ Server acknowledged shutdown request")
                    } else {
                        print("[SocialEffects] ⚠️ Shutdown API returned HTTP \(httpResponse.statusCode)")
                    }
                }
                // Give the server a moment to shut down
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            } catch {
                print("[SocialEffects] ⚠️ Graceful shutdown via API failed: \(error.localizedDescription)")
            }
        }
        
        // Give server time to shut down, then verify
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        let stillResponding = await checkHealth()
        if !stillResponding {
            print("[SocialEffects] ✅ Server no longer responding to health checks")
        } else {
            print("[SocialEffects] ⚠️ Server still responding after API shutdown")
        }
        
        // Force terminate if we have a process that's still running
        if let process = process {
            if process.isRunning {
                print("[SocialEffects] 🛑 Terminating process (PID: \(process.processIdentifier))...")
                process.terminate()
                
                // Wait for termination
                try? await Task.sleep(nanoseconds: UInt64(AppConfiguration.Timeouts.shutdown * 1_000_000_000))
                
                if process.isRunning {
                    // Force kill using POSIX signal
                    print("[SocialEffects] ⚠️ Process still running, force killing...")
                    kill(process.processIdentifier, SIGKILL)
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                } else {
                    print("[SocialEffects] ✅ Process terminated gracefully")
                }
            } else {
                print("[SocialEffects] Process already terminated")
            }
        } else if isExternalServer && stillResponding {
            // We don't have a process reference but server is still running
            print("[SocialEffects] Attempting to kill external server by port...")
            await killProcessByPort(serverPort)
        } else {
            print("[SocialEffects] No process reference to terminate")
        }
        
        isRunning = false
        isExternalServer = false
        process = nil
        print("[SocialEffects] ✅ Shutdown sequence complete")
    }
    
    /// Returns whether the server is currently running
    /// Uses health check as primary indicator, with process liveness for our managed instances
    var serverIsRunning: Bool {
        get async {
            // Always check health first - this works for both our process and external servers
            let healthy = await checkHealth()
            if healthy {
                return true
            }
            
            // Health check failed - check if our managed process died
            if let process = process {
                if !process.isRunning {
                    if Log.isDebugMode {
                        Log.debug("Social Effects process terminated unexpectedly", category: "SocialEffects")
                    }
                    isRunning = false
                    self.process = nil
                } else {
                    // Process exists but not healthy - might be starting up or in bad state
                    if Log.isDebugMode {
                        Log.debug("Social Effects process running but not healthy", category: "SocialEffects")
                    }
                }
            } else if isRunning {
                // Process is nil but flag says running - we thought we started it but it's gone
                if Log.isDebugMode {
                    Log.debug("Social Effects process nil but flag says running - resetting state", category: "SocialEffects")
                }
                isRunning = false
            }
            
            return false
        }
    }

    /// Attempts to kill a process listening on the specified port
    private func killProcessByPort(_ port: UInt16) async {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "lsof -i :\(port) -t | xargs kill -9 2>/dev/null || true"]
        
        do {
            try task.run()
            task.waitUntilExit()
            print("[SocialEffects] Sent kill signal to process on port \(port)")
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        } catch {
            print("[SocialEffects] Failed to kill process by port: \(error.localizedDescription)")
        }
    }
}
