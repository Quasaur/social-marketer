//
//  VideoHostingService.swift
//  SocialMarketer
//
//  Temporary HTTP server + tunnel for Instagram video hosting
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.wisdombook.SocialMarketer", category: "VideoHosting")

enum VideoHostingError: Error {
    case tunnelStartFailed(String)
    case serverStartFailed
}

/// Provides a publicly accessible URL for local video files
final class VideoHostingService {
    static let shared = VideoHostingService()
    
    private var pythonProcess: Process?
    private var tunnelProcess: Process?
    private var serverPort: Int = 0
    
    private init() {}
    
    func hostVideo(_ videoURL: URL) async throws -> String {
        await stopServer()
        
        serverPort = findAvailablePort()
        logger.info("Using port \(self.serverPort)")
        
        let videoDirectory = videoURL.deletingLastPathComponent().path
        let videoFilename = videoURL.lastPathComponent
        
        // Start Python HTTP server
        logger.info("Starting HTTP server...")
        try startPythonServer(directory: videoDirectory)
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Start localtunnel with better error handling
        logger.info("Starting localtunnel...")
        let tunnelURL = try await startLocaltunnel(port: serverPort)
        
        let videoPublicURL = "\(tunnelURL)/\(videoFilename)"
        logger.info("Video URL: \(videoPublicURL)")
        
        // Wait for tunnel propagation
        try await Task.sleep(nanoseconds: 3_000_000_000)
        
        return videoPublicURL
    }
    
    private func findAvailablePort() -> Int {
        for port in 8765...9000 {
            if isPortAvailable(port) {
                return port
            }
        }
        return 8765
    }
    
    private func isPortAvailable(_ port: Int) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "lsof -i :\(port) 2>/dev/null | grep -q LISTEN && echo 'in use' || echo 'available'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return output.contains("available")
        } catch {
            return true
        }
    }
    
    func stopServer() async {
        logger.info("Stopping servers...")
        
        if let process = pythonProcess {
            process.terminate()
            process.waitUntilExit()
            pythonProcess = nil
        }
        
        if let process = tunnelProcess {
            process.terminate()
            process.waitUntilExit()
            tunnelProcess = nil
        }
        
        // Kill any leftover processes on our port
        let port = serverPort
        let killTask = Process()
        killTask.executableURL = URL(fileURLWithPath: "/bin/bash")
        killTask.arguments = ["-c", "pkill -f 'http.server.*\(port)' 2>/dev/null; pkill -f 'lt --port \(port)' 2>/dev/null"]
        try? killTask.run()
        killTask.waitUntilExit()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    private func startPythonServer(directory: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "http.server", "\(serverPort)", "--directory", directory]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        pythonProcess = process
        let port = serverPort
        logger.info("HTTP server started on port \(port)")
    }
    
    private func startLocaltunnel(port: Int) async throws -> String {
        // Create a temporary file for output
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("localtunnel_\(UUID().uuidString).txt")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        
        // Run lt and capture output to temp file with timeout
        let script = """
        export PATH="/Users/quasaur/.nvm/versions/node/v20.19.6/bin:$PATH"
        /Users/quasaur/.nvm/versions/node/v20.19.6/bin/lt --port \(port) > \(tempFile.path) 2>&1 &
        LT_PID=$!
        sleep 15
        kill $LT_PID 2>/dev/null
        wait $LT_PID 2>/dev/null
        cat \(tempFile.path)
        rm \(tempFile.path)
        """
        
        process.arguments = ["-c", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        tunnelProcess = process
        
        // Read output with timeout
        let fileHandle = pipe.fileHandleForReading
        var allOutput = ""
        
        // Wait up to 20 seconds
        for _ in 0..<40 {
            try await Task.sleep(nanoseconds: 500_000_000)
            
            if let data = try? fileHandle.read(upToCount: 1024),
               let output = String(data: data, encoding: .utf8) {
                allOutput += output
                
                if let url = extractTunnelURL(from: allOutput) {
                    // Keep the process running but we got the URL
                    return url
                }
            }
            
            if !process.isRunning {
                break
            }
        }
        
        // Process finished or timed out, read any remaining output
        let remainingData = fileHandle.readDataToEndOfFile()
        if let output = String(data: remainingData, encoding: .utf8) {
            allOutput += output
        }
        
        if let url = extractTunnelURL(from: allOutput) {
            return url
        }
        
        logger.error("Failed to get tunnel. Output: \(allOutput)")
        throw VideoHostingError.tunnelStartFailed("localtunnel failed. Output: \(allOutput.prefix(300))")
    }
    
    private func extractTunnelURL(from output: String) -> String? {
        // Pattern: "your url is: https://xxxx.loca.lt"
        if let range = output.range(of: "your url is: ", options: .caseInsensitive) {
            let after = String(output[range.upperBound...])
            if let urlEnd = after.firstIndex(where: { $0.isWhitespace || $0 == "\n" }) {
                let url = String(after[..<urlEnd])
                if url.hasPrefix("https://") && url.contains("loca.lt") {
                    return url
                }
            }
        }
        
        // Pattern: direct https://xxxx.loca.lt
        if let range = output.range(of: "https://[a-zA-Z0-9-]+\\.loca\\.lt", options: .regularExpression) {
            return String(output[range])
        }
        
        return nil
    }
    
    deinit {
        Task {
            await stopServer()
        }
    }
}

extension VideoHostingError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .tunnelStartFailed(let message):
            return "Tunnel failed: \(message)"
        case .serverStartFailed:
            return "Failed to start HTTP server."
        }
    }
}
