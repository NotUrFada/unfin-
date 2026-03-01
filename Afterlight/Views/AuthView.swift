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
    private var primaryFg: Color { AppTheme.Colors.primaryText(isLight: isLight) }
    private var secondaryFg: Color { AppTheme.Colors.secondaryText(isLight: isLight) }
    private var surfaceOpacity: Double { AppTheme.Colors.surfaceOpacity(isLight: isLight) }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradientView()

                VStack(spacing: AppTheme.Spacing.xxl) {
                    Spacer()
                    UnfinWordmark(size: 28, color: primaryFg)
                    Spacer()

                    VStack(spacing: AppTheme.Spacing.lg) {
                        NavigationLink(value: AuthDest.login) {
                            Text("Log In")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(isLight ? .white : Color(white: 0.12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                                .background(primaryFg)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(AuthPrimaryButtonStyle())

                        NavigationLink(value: AuthDest.signUp) {
                            Text("Sign Up")
                                .font(AppTheme.Typography.headline)
                                .foregroundStyle(primaryFg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.lg)
                                .background(primaryFg.opacity(surfaceOpacity))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(primaryFg.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(AuthPrimaryButtonStyle())
                    }
                    .padding(.horizontal, AppTheme.Spacing.screenHorizontal)
                    .padding(.bottom, AppTheme.Spacing.xxl + 16)
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
