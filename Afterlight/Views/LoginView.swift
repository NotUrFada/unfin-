//
//  LoginView.swift
//  Unfin
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: IdeaStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?
    
    enum Field { case email, password }
    
    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Log In")
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
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    
                    Button {
                        if store.login(email: email, password: password) {
                            dismiss()
                        }
                    } label: {
                        Text("Log In")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(white: 0.12))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    
                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(white: 0.12), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
        .onAppear { store.authError = nil }
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(IdeaStore())
    }
}
