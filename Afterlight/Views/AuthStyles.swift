//
//  AuthStyles.swift
//  Unfin
//
//  Shared styles for Login and Sign Up (e.g. primary button press feedback).
//

import SwiftUI

struct AuthPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
