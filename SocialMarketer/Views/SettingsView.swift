//
//  SettingsView.swift
//  SocialMarketer
//
//  Created on 2026-02-05.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            // Placeholder for settings
            Text("Settings coming soon...")
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
}
