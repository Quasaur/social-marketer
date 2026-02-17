//
//  LaunchdManager.swift
//  SocialMarketer
//
//  Manages launchd agent installation, updates, and removal for background scheduling.
//  Extracted from PostScheduler.swift to follow Single Responsibility Principle.
//

import Foundation

/// Handles launchd agent lifecycle for background post scheduling.
@MainActor
final class LaunchdManager {
    
    private let logger = Log.scheduler
    
    // MARK: - Configuration
    
    static let launchdLabel = "com.wisdombook.SocialMarketer"
    static let launchdPlistName = "com.wisdombook.SocialMarketer.plist"
    
    /// UserDefaults keys for configurable schedule time
    static let scheduleHourKey = "launchd.scheduleHour"
    static let scheduleMinuteKey = "launchd.scheduleMinute"
    
    /// Current schedule time (defaults to 9:00 AM)
    static var scheduledHour: Int {
        get {
            let stored = UserDefaults.standard.integer(forKey: scheduleHourKey)
            // 0 is both the default and midnight — use a sentinel to distinguish
            return UserDefaults.standard.object(forKey: scheduleHourKey) != nil ? stored : 9
        }
        set { UserDefaults.standard.set(newValue, forKey: scheduleHourKey) }
    }
    
    static var scheduledMinute: Int {
        get { UserDefaults.standard.integer(forKey: scheduleMinuteKey) }
        set { UserDefaults.standard.set(newValue, forKey: scheduleMinuteKey) }
    }
    
    private static var launchAgentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }
    
    private static var installedPlistURL: URL {
        launchAgentsURL.appendingPathComponent(launchdPlistName)
    }
    
    // MARK: - Optimal Posting Times (EST)
    
    struct PostingSchedule {
        static let twitter = DateComponents(hour: 9, minute: 0)
        static let linkedin = DateComponents(hour: 10, minute: 0)
        static let facebook = DateComponents(hour: 13, minute: 0)
        static let instagram = DateComponents(hour: 18, minute: 0)
        static let pinterest = DateComponents(hour: 14, minute: 0)
    }
    
    // MARK: - Status
    
    /// Check if the launch agent is installed
    var isLaunchAgentInstalled: Bool {
        FileManager.default.fileExists(atPath: Self.installedPlistURL.path)
    }
    
    // MARK: - Management
    
    /// Auto-install or update the launch agent if the executable path or schedule has changed.
    /// Called on every app launch to self-heal after DerivedData wipes or schedule changes.
    func ensureLaunchAgentCurrent() {
        guard isLaunchAgentInstalled else { return } // respect user's toggle choice
        
        // Read the installed plist and compare executable path + schedule
        guard let data = try? Data(contentsOf: Self.installedPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let args = plist["ProgramArguments"] as? [String],
              let schedule = plist["StartCalendarInterval"] as? [String: Int] else {
            // Can't read — reinstall
            try? installLaunchAgent()
            return
        }
        
        let installedPath = args.first ?? ""
        let currentPath = Bundle.main.executableURL?.path ?? ""
        let installedHour = schedule["Hour"] ?? -1
        let installedMinute = schedule["Minute"] ?? -1
        
        if installedPath != currentPath || installedHour != Self.scheduledHour || installedMinute != Self.scheduledMinute {
            logger.info("Launch agent outdated — reinstalling (path or schedule changed)")
            try? installLaunchAgent()
        } else {
            logger.debug("Launch agent is current")
        }
    }
    
    /// Install the launch agent for background scheduling
    func installLaunchAgent() throws {
        let fileManager = FileManager.default
        
        // Create LaunchAgents directory if needed
        if !fileManager.fileExists(atPath: Self.launchAgentsURL.path) {
            try fileManager.createDirectory(at: Self.launchAgentsURL, withIntermediateDirectories: true)
        }
        
        // Get the actual executable path from the running app
        guard let executableURL = Bundle.main.executableURL else {
            throw SchedulerError.plistNotFound
        }
        
        // Build plist dictionary with the actual app path
        let plistDict: [String: Any] = [
            "Label": Self.launchdLabel,
            "ProgramArguments": [executableURL.path, "--scheduled-post"],
            "StartCalendarInterval": ["Hour": Self.scheduledHour, "Minute": Self.scheduledMinute],
            "RunAtLoad": false,
            "KeepAlive": false,
            "StandardOutPath": "/tmp/com.wisdombook.SocialMarketer.out.log",
            "StandardErrorPath": "/tmp/com.wisdombook.SocialMarketer.err.log",
            "EnvironmentVariables": ["PATH": "/usr/local/bin:/usr/bin:/bin"],
            "WorkingDirectory": "/tmp",
            "ProcessType": "Background",
            "Nice": 10
        ]
        
        // Write the plist
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict,
            format: .xml,
            options: 0
        )
        
        // Remove existing if present
        if fileManager.fileExists(atPath: Self.installedPlistURL.path) {
            // Unload first
            let unloadProcess = Process()
            unloadProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadProcess.arguments = ["unload", Self.installedPlistURL.path]
            try? unloadProcess.run()
            unloadProcess.waitUntilExit()
            
            try fileManager.removeItem(at: Self.installedPlistURL)
        }
        
        try plistData.write(to: Self.installedPlistURL)
        
        // Load the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", Self.installedPlistURL.path]
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw SchedulerError.launchctlFailed("load")
        }
        
        logger.info("Launch agent installed and loaded from \(executableURL.path)")
    }
    
    /// Uninstall the launch agent
    func uninstallLaunchAgent() throws {
        // Unload the agent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", Self.installedPlistURL.path]
        try process.run()
        process.waitUntilExit()
        
        // Remove the plist
        if FileManager.default.fileExists(atPath: Self.installedPlistURL.path) {
            try FileManager.default.removeItem(at: Self.installedPlistURL)
        }
        
        logger.info("Launch agent unloaded and removed")
    }
}

// MARK: - Errors

enum SchedulerError: Error, LocalizedError {
    case plistNotFound
    case launchctlFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .plistNotFound:
            return "Launch agent plist not found in app bundle"
        case .launchctlFailed(let command):
            return "launchctl \(command) failed"
        }
    }
}
