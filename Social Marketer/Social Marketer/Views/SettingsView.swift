//
//  SettingsView.swift
//  SocialMarketer
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("postingHour") private var postingHour = 9
    @AppStorage("postingMinute") private var postingMinute = 0
    @AppStorage("includeHashtags") private var includeHashtags = true
    @AppStorage("includeEmoji") private var includeEmoji = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            Form {
                Section("Posting Schedule") {
                    HStack {
                        Text("Daily Post Time")
                        Spacer()
                        Picker("Hour", selection: $postingHour) {
                            ForEach(0..<24) { hour in
                                Text(String(format: "%02d", hour)).tag(hour)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                        
                        Text(":")
                        
                        Picker("Minute", selection: $postingMinute) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 60)
                    }
                    
                    Text("The scheduler runs daily at this time (your local timezone).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Post Formatting") {
                    Toggle("Include hashtags (#wisdom #wisdombook)", isOn: $includeHashtags)
                    Toggle("Include emoji (🔗 📖)", isOn: $includeEmoji)
                }
                
                Section("Content Source") {
                    LabeledContent("RSS Feed") {
                        Text("wisdombook.life/feed/daily.xml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Link("View Feed", destination: URL(string: "https://wisdombook.life/feed/daily.xml")!)
                        .font(.caption)
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
