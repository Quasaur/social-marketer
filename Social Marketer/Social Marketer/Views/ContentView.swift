//
//  ContentView.swift
//  SocialMarketer
//
//  Main content view with tab navigation
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = "dashboard"
    
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List(selection: $selectedTab) {
                Section("Overview") {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                        .tag("dashboard")
                    Label("Content", systemImage: "doc.text")
                        .tag("content")
                    Label("Queue", systemImage: "tray.and.arrow.up")
                        .tag("queue")
                }
                
                Section("Monitoring") {
                    Label("Admin Dashboard", systemImage: "chart.bar.doc.horizontal")
                        .tag("admin")
                }
                
                Section("Configuration") {
                    Label("Platforms", systemImage: "square.stack.3d.up")
                        .tag("platforms")
                    Label("Discovery", systemImage: "safari")
                        .tag("discovery")
                    Label("Settings", systemImage: "gear")
                        .tag("settings")
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            // Main content
            switch selectedTab {
            case "dashboard":
                DashboardView()
            case "content":
                ContentBrowserView()
            case "queue":
                QueueView()
            case "admin":
                AdminDashboardView()
            case "platforms":
                PlatformSettingsView()
            case "discovery":
                DiscoveryView()
            case "settings":
                SettingsView()
            default:
                DashboardView()
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
