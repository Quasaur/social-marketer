//
//  LoggingService.swift
//  SocialMarketer
//
//  Centralized Universal Logging System (ULS) integration.
//  All logs flow through macOS' os.log and appear in Console.app
//  and via the `log` Terminal command.
//

import Foundation
@_exported import os.log

/// Centralized ULS logging for Social Marketer.
///
/// Usage:  `Log.app.info("Something happened")`
///         `Log.scheduler.error("Post failed: \(error)")`
enum Log {

    // MARK: - Subsystem

    /// Single subsystem identifier used for all Social Marketer logs.
    static let subsystem = "com.wisdombook.SocialMarketer"

    // MARK: - Category Loggers

    /// App lifecycle (launch, seed, shutdown)
    static let app          = Logger(subsystem: subsystem, category: "App")

    /// Post scheduler & queue processing
    static let scheduler    = Logger(subsystem: subsystem, category: "Scheduler")

    /// Core Data persistence
    static let persistence  = Logger(subsystem: subsystem, category: "Persistence")

    /// Twitter / X connector
    static let twitter      = Logger(subsystem: subsystem, category: "Twitter")

    /// Instagram connector
    static let instagram    = Logger(subsystem: subsystem, category: "Instagram")

    /// LinkedIn connector
    static let linkedin     = Logger(subsystem: subsystem, category: "LinkedIn")

    /// Facebook connector
    static let facebook     = Logger(subsystem: subsystem, category: "Facebook")

    /// Pinterest connector
    static let pinterest    = Logger(subsystem: subsystem, category: "Pinterest")

    /// YouTube API operations
    static let youtube      = Logger(subsystem: subsystem, category: "YouTube")

    /// TikTok API operations
    static let tiktok       = Logger(subsystem: subsystem, category: "TikTok")

    /// OAuth authentication flows
    static let oauth        = Logger(subsystem: subsystem, category: "OAuth")

    /// Keychain credential storage
    static let keychain     = Logger(subsystem: subsystem, category: "Keychain")

    /// Content browsing & caching
    static let content      = Logger(subsystem: subsystem, category: "ContentService")

    /// RSS feed parsing
    static let rss          = Logger(subsystem: subsystem, category: "RSS")

    /// Quote graphic generation
    static let graphic      = Logger(subsystem: subsystem, category: "Graphics")

    /// Google Indexing API
    static let indexing     = Logger(subsystem: subsystem, category: "GoogleIndexing")

    // MARK: - Debug Mode

    /// App-level debug mode flag, persisted in UserDefaults.
    /// When enabled, calls to `Log.debug(...)` will emit to the
    /// console and the Recent Errors panel so they're visible
    /// without needing `sudo log config`.
    static var isDebugMode: Bool {
        UserDefaults.standard.bool(forKey: "debugModeEnabled")
    }

    /// Emit a debug-level message that is visible when Debug Mode is on.
    /// Always logs via os.log at `.debug` level (memory-only by default).
    /// When Debug Mode is enabled, also prints to stdout and forwards
    /// to the ErrorLog service for in-app visibility.
    static func debug(_ message: String, category: String = "App") {
        // Always send to os.log (memory-only unless ULS is configured)
        let logger = Logger(subsystem: subsystem, category: category)
        logger.debug("\(message)")

        // When debug mode is on, also surface in-app
        if isDebugMode {
            print("[\(category)] [DEBUG] \(message)")
            Task { @MainActor in
                ErrorLog.shared.log(category: "Debug/\(category)", message: message)
            }
        }
    }

    // MARK: - Diagnostic Helpers

    /// A ready-to-paste Terminal command that shows the last hour of
    /// Social Marketer logs.
    static let diagnosticCommand =
        "log show --predicate 'subsystem == \"com.wisdombook.SocialMarketer\"' --last 1h --style compact"

    /// A ready-to-paste Terminal command that streams Social Marketer logs live.
    static let streamCommand =
        "log stream --predicate 'subsystem == \"com.wisdombook.SocialMarketer\"' --level debug"
}
