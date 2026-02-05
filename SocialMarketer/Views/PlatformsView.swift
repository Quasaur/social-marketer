//
//  PlatformsView.swift
//  SocialMarketer
//
//  Created on 2026-02-05.
//

import SwiftUI

struct PlatformsView: View {
    var body: some View {
        VStack {
            Text("Platforms")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Manage your 18 social media platforms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Placeholder for platforms list
            Text("Platform management coming soon...")
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Platforms")
    }
}

#Preview {
    PlatformsView()
}
