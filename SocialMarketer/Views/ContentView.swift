//
//  ContentView.swift
//  SocialMarketer
//
//  Created on 2026-02-05.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            // Sidebar
            List {
                NavigationLink("Dashboard", destination: DashboardView())
                NavigationLink("Platforms", destination: PlatformsView())
                NavigationLink("Content", destination: ContentView())
                NavigationLink("Settings", destination: SettingsView())
            }
            .navigationTitle("Social Marketer")
        } detail: {
            // Main content area
            DashboardView()
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
