//
//  SettingsView.swift
//  SocialMarketer
//
//  App settings and preferences
//

import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("includeHashtags") private var includeHashtags = true
    @AppStorage("includeEmoji") private var includeEmoji = true
    @AppStorage("debugModeEnabled") private var debugModeEnabled = false
    @State private var copiedCommand = false
    @State private var isRestoring = false
    @State private var showingBackupAlert = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""
    
    private let backupManager = CredentialBackupManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Form {
                Section("Credential Backup") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Platform Credentials")
                                .font(.body)
                            if let lastBackup = backupManager.lastBackupDate() {
                                Text("Last backup: \(lastBackup, style: .relative) ago")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(backupManager.backupSummary())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No backup found")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            restoreCredentials()
                        } label: {
                            HStack(spacing: 4) {
                                if isRestoring {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "arrow.counterclockwise")
                                }
                                Text("Restore from Backup")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!backupManager.backupExists() || isRestoring)
                    }
                    
                    Text("Credentials are backed up automatically when platforms are configured. Restore pre-fills API keys — you'll still need to click 'Connect' for each platform.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Post Formatting") {
                    Toggle("Include hashtags (#wisdom #wisdombook)", isOn: $includeHashtags)
                        .toggleStyle(.status)
                    Toggle("Include emoji (🔗 📖)", isOn: $includeEmoji)
                        .toggleStyle(.status)
                }
                
                Section("Content Source") {
                    LabeledContent("RSS Feed") {
                        Text("wisdombook.life/feed/daily.xml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link("View Feed", destination: URL(string: "https://www.wisdombook.life/feed/daily.xml")!)
                        .font(.caption)
                }
                
                Section("Diagnostics") {
                    Toggle("Debug Mode", isOn: $debugModeEnabled)
                        .toggleStyle(.status)
                        .onChange(of: debugModeEnabled) { _, newValue in
                            Log.app.info("Debug mode \(newValue ? "enabled" : "disabled")")
                        }
                    
                    Text("When enabled, verbose debug messages appear in the Recent Errors panel on the Dashboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(Log.diagnosticCommand, forType: .string)
                        copiedCommand = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            copiedCommand = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: copiedCommand ? "checkmark" : "doc.on.doc")
                            Text(copiedCommand ? "Copied!" : "Copy Diagnostic Command")
                        }
                    }
                    
                    Text("Copies a Terminal command that shows the last hour of Social Marketer logs.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("App Info") {
                    LabeledContent("Version") {
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    }
                    
                    LabeledContent("Build") {
                        Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding(.top)
        .alert(backupAlertTitle, isPresented: $showingBackupAlert) {
            Button("OK") {}
        } message: {
            Text(backupAlertMessage)
        }
    }
    
    private func restoreCredentials() {
        isRestoring = true
        defer { isRestoring = false }
        
        do {
            let backup = try backupManager.restoreFromBackup()
            var platforms: [String] = []
            if backup.twitter != nil { platforms.append("Twitter") }
            if backup.facebook != nil { platforms.append("Facebook") }
            if backup.instagram != nil { platforms.append("Instagram") }
            if backup.linkedin != nil { platforms.append("LinkedIn") }
            if backup.pinterest != nil { platforms.append("Pinterest") }
            
            backupAlertTitle = "Credentials Restored"
            backupAlertMessage = "Restored API keys for: \(platforms.joined(separator: ", ")).\n\nGo to Platforms and click 'Connect' for each to authorize via OAuth."
            showingBackupAlert = true
        } catch {
            backupAlertTitle = "Restore Failed"
            backupAlertMessage = error.localizedDescription
            showingBackupAlert = true
        }
    }
}

#Preview {
    SettingsView()
}
