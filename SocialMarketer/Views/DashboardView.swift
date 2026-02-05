//
//  DashboardView.swift
//  SocialMarketer
//
//  Created on 2026-02-05.
//

import SwiftUI

struct DashboardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Social Marketer")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Multi-Platform Content Distribution")
                .font(.title3)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Placeholder for dashboard content
            VStack(spacing: 16) {
                DashboardCard(title: "Active Platforms", value: "0/18")
                DashboardCard(title: "Pending Posts", value: "0")
                DashboardCard(title: "Published Today", value: "0")
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("Dashboard")
    }
}

struct DashboardCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    DashboardView()
}
