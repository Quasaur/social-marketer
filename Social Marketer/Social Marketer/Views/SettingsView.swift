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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Form {
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
    }
}

#Preview {
    SettingsView()
}
