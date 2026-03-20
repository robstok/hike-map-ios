import SwiftUI
import Supabase

enum AuthMode { case signIn, signUp, forgotPassword }

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var mode: AuthMode = .signIn

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "#0d1117"), Color(hex: "#0F1A2A")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Decorative blob
            Circle()
                .fill(Config.accent.opacity(0.06))
                .frame(width: 400, height: 400)
                .offset(x: 150, y: -200)
                .blur(radius: 60)

            VStack(spacing: 0) {
                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "mountain.2.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(colors: [Config.accent, Color(hex: "#FF9962")],
                                          startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Hitrekk")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(colors: [Config.accent, Color(hex: "#FF9962")],
                                          startPoint: .leading, endPoint: .trailing)
                        )
                    Text("3D Hiking Explorer")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 32)

                // Card
                VStack(spacing: 0) {
                    // Tabs (only for signIn/signUp)
                    if mode != .forgotPassword {
                        HStack(spacing: 0) {
                            TabButton(title: "Sign In", isActive: mode == .signIn) { mode = .signIn }
                            TabButton(title: "Create Account", isActive: mode == .signUp) { mode = .signUp }
                        }
                        .background(Color(hex: "#161B22"))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.bottom, 20)
                    }

                    // Form
                    switch mode {
                    case .signIn:         SignInForm(onForgotPassword: { mode = .forgotPassword })
                    case .signUp:         SignUpForm()
                    case .forgotPassword: ForgotPasswordForm(onBack: { mode = .signIn })
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#161B22"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.07), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 40, y: 20)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct TabButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .foregroundStyle(isActive ? Config.accent : .secondary)
                .overlay(alignment: .bottom) {
                    if isActive {
                        Rectangle().fill(Config.accent).frame(height: 2)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Sign In

struct SignInForm: View {
    @EnvironmentObject var appState: AppState
    var onForgotPassword: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(label: "Email", text: $email, keyboard: .emailAddress)
            AuthTextField(label: "Password", text: $password, isSecure: true)

            HStack {
                Spacer()
                Button("Forgot password?", action: onForgotPassword)
                    .font(.system(size: 12))
                    .foregroundStyle(Config.accent)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await signIn() }
            } label: {
                Group {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text("Sign In").fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Config.accent)
            .disabled(isLoading || email.isEmpty || password.isEmpty)
        }
    }

    private func signIn() async {
        isLoading = true; errorMessage = ""
        do {
            try await appState.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: — Sign Up

struct SignUpForm: View {
    @EnvironmentObject var appState: AppState

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var isSuccess = false

    var body: some View {
        VStack(spacing: 16) {
            AuthTextField(label: "Full Name", text: $fullName)
            AuthTextField(label: "Email", text: $email, keyboard: .emailAddress)
            AuthTextField(label: "Password", text: $password, isSecure: true)
            AuthTextField(label: "Confirm Password", text: $confirm, isSecure: true)

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(isSuccess ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await signUp() }
            } label: {
                Group {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text("Create Account").fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Config.accent)
            .disabled(isLoading || email.isEmpty || password.isEmpty || confirm.isEmpty)
        }
    }

    private func signUp() async {
        guard password == confirm else { message = "Passwords don't match"; return }
        isLoading = true; message = ""
        do {
            try await appState.signUp(email: email, password: password, fullName: fullName)
            isSuccess = true
            message = "Check your email to confirm your account"
        } catch {
            isSuccess = false
            message = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: — Forgot Password

struct ForgotPasswordForm: View {
    @EnvironmentObject var appState: AppState
    var onBack: () -> Void

    @State private var email = ""
    @State private var isLoading = false
    @State private var message = ""
    @State private var isSuccess = false

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Config.accent)
                }
                Text("Reset Password")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }

            AuthTextField(label: "Email", text: $email, keyboard: .emailAddress)

            if !message.isEmpty {
                Text(message).font(.system(size: 12))
                    .foregroundStyle(isSuccess ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await reset() }
            } label: {
                Group {
                    if isLoading { ProgressView().tint(.white) }
                    else { Text("Send Reset Link").fontWeight(.semibold) }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Config.accent)
            .disabled(isLoading || email.isEmpty)
        }
    }

    private func reset() async {
        isLoading = true; message = ""
        do {
            try await appState.resetPassword(email: email)
            isSuccess = true; message = "Check your email for a reset link"
        } catch {
            isSuccess = false; message = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: — Shared text field

struct AuthTextField: View {
    let label: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                        .keyboardType(keyboard)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            }
            .font(.system(size: 14))
            .padding(.vertical, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.15))
                    .frame(height: 1)
            }
        }
    }
}
