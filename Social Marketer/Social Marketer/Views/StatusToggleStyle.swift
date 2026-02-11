//
//  StatusToggleStyle.swift
//  SocialMarketer
//
//  Custom toggle style with green (on) / red (off) backgrounds
//  for improved visibility against the app's dark color theme
//

import SwiftUI

/// A toggle style that uses green for "on" and red for "off"
/// to make the state clearly visible regardless of color theme.
struct StatusToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            ZStack {
                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.red.opacity(0.7))
                    .frame(width: 44, height: 24)
                
                Circle()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}

extension ToggleStyle where Self == StatusToggleStyle {
    static var status: StatusToggleStyle { StatusToggleStyle() }
}
