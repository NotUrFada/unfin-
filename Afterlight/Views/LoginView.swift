//
//  LoginView.swift
//  Unfin
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var isBusy = false
    @FocusState private var focusedField: Field?

    private var isLight: Bool { colorScheme == .light }
    private var primaryFg: Color { AppTheme.Colors.primaryText(isLight: isLight) }
    private var secondaryFg: Color { AppTheme.Colors.secondaryText(isLight: isLight) }
    private var surfaceOpacity: Double { AppTheme.Colors.surfaceOpacity(isLight: isLight) }

    enum Field { case email, password }

    var body: some View {
        ZStack {
            BackgroundGradientView()

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
                    Text("Log In")
                        .font(AppTheme.Typography.titleLarge)
                        .foregroundStyle(primaryFg)
                        .padding(.top, AppTheme.Spacing.headerTop)

                    if let error = store.authError {
                        Text(error)
                            .font(AppTheme.Typography.bodySmall)
                            .foregroundStyle(.red)
                            .padding(AppTheme.Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    authField(
                        label: "Email",
                        placeholder: "you@example.com",
                        text: $email,
                        isFocused: focusedField == .email
                    ) {
                        TextField("", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                    }

                    authField(
                        label: "Password",
                        placeholder: "Password",
                        text: $password,
                        isFocused: focusedField == .password
                    ) {
                        SecureField("", text: $password)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    }

                    Button {
                        isBusy = true
                        focusedField = nil
                        store.authError = nil
                        Task {
                            do {
                                try await store.login(email: email, password: password)
                                await MainActor.run { dismiss() }
                            } catch {
                                await MainActor.run {
                                    let msg = error.localizedDescription
                                    store.authError = (msg.isEmpty || msg.contains("it isn't") || msg.contains("not found"))
                                        ? "Invalid email or password. If you just signed up, check your inbox to confirm your email."
                                        : msg
                                    isBusy = false
                                }
                            }
                        }
                    } label: {
                        Text(isBusy ? "Signing in…" : "Log In")
                            .font(AppTheme.Typography.headline)
                            .foregroundStyle(isLight ? .white : Color(white: 0.12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.lg)
                            .background(primaryFg)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(AuthPrimaryButtonStyle())
                    .disabled(isBusy)
                    .padding(.top, AppTheme.Spacing.sm)

                    Spacer(minLength: 40)
                }
                .padding(AppTheme.Spacing.screenHorizontal)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { store.authError = nil }
    }

    @ViewBuilder
    private func authField<Content: View>(
        label: String,
        placeholder: String,
        text: Binding<String>,
        isFocused: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(label)
                .font(AppTheme.Typography.bodySmall)
                .fontWeight(.semibold)
                .foregroundStyle(secondaryFg)
            ZStack(alignment: .leading) {
                content()
                    .foregroundStyle(primaryFg)
                    .tint(primaryFg)
                    .padding(AppTheme.Spacing.lg)
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(primaryFg.opacity(0.5))
                        .padding(.leading, AppTheme.Spacing.lg)
                        .allowsHitTesting(false)
                }
            }
            .background(primaryFg.opacity(isFocused ? surfaceOpacity + 0.04 : surfaceOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(primaryFg.opacity(isFocused ? 0.5 : 0.2), lineWidth: isFocused ? 2 : 1)
            )
            .animation(.easeOut(duration: 0.22), value: isFocused)
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(IdeaStore())
    }
}
