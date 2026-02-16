//
//  SignUpView.swift
//  Unfin
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var isBusy = false
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password, displayName }
    
    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Sign Up")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 24)
                    
                    if let error = store.authError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Display name")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        TextField("How you'll appear", text: $displayName)
                            .textContentType(.username)
                            .focused($focusedField, equals: .displayName)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    
                    Button {
                        isBusy = true
                        store.authError = nil
                        Task {
                            do {
                                try await store.signUp(email: email, password: password, displayName: displayName)
                                await MainActor.run { dismiss() }
                            } catch {
                                await MainActor.run {
                                    store.authError = error.localizedDescription
                                    isBusy = false
                                }
                            }
                        }
                    } label: {
                        Text(isBusy ? "Creating account…" : "Sign Up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(white: 0.12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(isBusy)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { store.authError = nil }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
            .environmentObject(IdeaStore())
    }
}
