import SwiftUI

// MARK: - Login View
// Email + 6-digit code authentication

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var email: String = ""
    @State private var code: String = ""
    @FocusState private var isEmailFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            // Background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            // Glow orbs
            GlowOrbBackground(
                color: TunedUpTheme.Colors.cyan,
                size: 500,
                position: CGPoint(x: UIScreen.main.bounds.width / 2, y: 150)
            )

            GlowOrbBackground(
                color: TunedUpTheme.Colors.magenta,
                size: 400,
                position: CGPoint(x: 50, y: UIScreen.main.bounds.height - 150)
            )

            // Content
            VStack(spacing: TunedUpTheme.Spacing.xxl) {
                Spacer()

                // Logo area
                VStack(spacing: TunedUpTheme.Spacing.lg) {
                    // Logo icon
                    ZStack {
                        Circle()
                            .fill(TunedUpTheme.Colors.cyan.opacity(0.15))
                            .frame(width: 100, height: 100)

                        Image(systemName: "wrench.and.screwdriver")
                            .font(.system(size: 44))
                            .foregroundColor(TunedUpTheme.Colors.cyan)
                    }

                    // App name
                    Text("TunedUp")
                        .font(TunedUpTheme.Typography.heroTitle)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text("AI-Powered Build Plans")
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                }

                Spacer()

                // Login form
                VStack(spacing: TunedUpTheme.Spacing.lg) {
                    switch viewModel.authState {
                    case .unauthenticated, .unknown:
                        EmailInputSection(
                            email: $email,
                            isEmailFocused: $isEmailFocused,
                            isLoading: viewModel.isLoading,
                            onSubmit: {
                                Task {
                                    await viewModel.requestMagicLink(email: email)
                                }
                            }
                        )

                    case .awaitingCode(let sentEmail):
                        CodeSentSection(
                            email: sentEmail,
                            code: $code,
                            isCodeFocused: $isCodeFocused,
                            isLoading: viewModel.isLoading,
                            onVerify: {
                                Task {
                                    await viewModel.verifyCode(email: sentEmail, code: code)
                                }
                            },
                            onResend: {
                                Task {
                                    await viewModel.requestMagicLink(email: sentEmail)
                                }
                            },
                            onChangeEmail: {
                                viewModel.authState = .unauthenticated
                            }
                        )

                    case .awaitingPin:
                        // This shouldn't happen on login view
                        EmptyView()

                    case .authenticated:
                        // Navigate away
                        EmptyView()
                    }

                    // Error message
                    if let error = viewModel.error {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(TunedUpTheme.Colors.error)
                            Text(error)
                                .font(TunedUpTheme.Typography.footnote)
                                .foregroundColor(TunedUpTheme.Colors.error)
                        }
                        .padding(TunedUpTheme.Spacing.sm)
                        .background(TunedUpTheme.Colors.error.opacity(0.1))
                        .cornerRadius(TunedUpTheme.Radius.small)
                    }
                }
                .padding(.horizontal, TunedUpTheme.Spacing.lg)

                Spacer()

                // Footer
                Text("By continuing, you agree to our Terms of Service")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .padding(.bottom, TunedUpTheme.Spacing.lg)
            }
        }
        .onTapGesture {
            isEmailFocused = false
        }
    }
}

// MARK: - Email Input Section

struct EmailInputSection: View {
    @Binding var email: String
    var isEmailFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let onSubmit: () -> Void

    var isValidEmail: Bool {
        email.isValidEmail
    }

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.md) {
            // Email field
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
                Text("EMAIL")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(1)

                TextField("you@example.com", text: $email)
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused(isEmailFocused)
                    .padding(TunedUpTheme.Spacing.md)
                    .background(TunedUpTheme.Colors.cardSurface)
                    .cornerRadius(TunedUpTheme.Radius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                            .stroke(
                                isEmailFocused.wrappedValue
                                    ? TunedUpTheme.Colors.cyan
                                    : TunedUpTheme.Colors.textTertiary.opacity(0.2),
                                lineWidth: isEmailFocused.wrappedValue ? 2 : 1
                            )
                    )
                    .onSubmit {
                        if isValidEmail {
                            onSubmit()
                        }
                    }
            }

            // Submit button
            Button(action: {
                Haptics.impact(.medium)
                onSubmit()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.pureBlack))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "envelope")
                        Text("Send Code")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isValidEmail || isLoading)
        }
    }
}

// MARK: - Code Sent Section

struct CodeSentSection: View {
    let email: String
    @Binding var code: String
    var isCodeFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let onVerify: () -> Void
    let onResend: () -> Void
    let onChangeEmail: () -> Void

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // Success icon
            ZStack {
                Circle()
                    .fill(TunedUpTheme.Colors.success.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 36))
                    .foregroundColor(TunedUpTheme.Colors.success)
            }

            // Text
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("Check your email")
                    .font(TunedUpTheme.Typography.title2)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text("We sent a 6-digit code to")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)

                Text(email)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.cyan)
            }

            // Code input
            VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
                Text("CODE")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
                    .tracking(1)

                TextField("123456", text: $code)
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .focused(isCodeFocused)
                    .padding(TunedUpTheme.Spacing.md)
                    .background(TunedUpTheme.Colors.cardSurface)
                    .cornerRadius(TunedUpTheme.Radius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                            .stroke(
                                isCodeFocused.wrappedValue
                                    ? TunedUpTheme.Colors.cyan
                                    : TunedUpTheme.Colors.textTertiary.opacity(0.2),
                                lineWidth: isCodeFocused.wrappedValue ? 2 : 1
                            )
                    )
            }

            Button(action: {
                Haptics.impact(.medium)
                onVerify()
            }) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.pureBlack))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.seal")
                        Text("Verify Code")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(code.count != 6 || isLoading)

            // Actions
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Button(action: {
                    Haptics.impact(.light)
                    onResend()
                }) {
                    Text("Resend Code")
                }
                .buttonStyle(SecondaryButtonStyle())

                Button(action: {
                    Haptics.impact(.light)
                    onChangeEmail()
                }) {
                    Text("Use different email")
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.top, TunedUpTheme.Spacing.md)
        }
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
