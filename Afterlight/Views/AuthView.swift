//
//  AuthView.swift
//  Unfin
//

import SwiftUI

private enum AuthDest: Hashable {
    case login
    case signUp
}

struct AuthView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.colorScheme) private var colorScheme

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { isLight ? Color(white: 0.12) : .white }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                VStack(spacing: 32) {
                    Spacer()
                    Image("Logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                    Text("UNFIN")
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.5)
                        .foregroundStyle(primaryFg)
                    Text("Finish the story before dark.")
                        .font(.system(size: 16))
                        .foregroundStyle(primaryFg.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()

                    VStack(spacing: 16) {
                        NavigationLink(value: AuthDest.login) {
                            Text("Log In")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isLight ? Color.white : Color(white: 0.12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(primaryFg)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)

                        NavigationLink(value: AuthDest.signUp) {
                            Text("Sign Up")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(primaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(primaryFg.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(primaryFg.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
            .navigationDestination(for: AuthDest.self) { dest in
                switch dest {
                case .login: LoginView()
                case .signUp: SignUpView()
                }
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(IdeaStore())
}
