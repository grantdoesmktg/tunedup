import SwiftUI

// MARK: - Login View
// Magic link authentication with email input

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var email: String = ""
    @FocusState private var isEmailFocused: Bool

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

                    case .awaitingMagicLink(let sentEmail):
                        MagicLinkSentSection(
                            email: sentEmail,
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
        .onOpenURL { url in
            // Handle magic link deep link
            if url.scheme == "tunedup" && url.host == "auth" {
                if let token = url.queryParameters?["token"] {
                    Task {
                        await viewModel.verifyMagicLink(token: token)
                    }
                }
            }
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
                        Text("Send Magic Link")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!isValidEmail || isLoading)
        }
    }
}

// MARK: - Magic Link Sent Section

struct MagicLinkSentSection: View {
    let email: String
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

                Text("We sent a magic link to")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)

                Text(email)
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.cyan)
            }

            // Actions
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Button(action: {
                    Haptics.impact(.light)
                    onResend()
                }) {
                    Text("Resend Link")
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

// MARK: - URL Extensions

extension URL {
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return nil }
        var params = [String: String]()
        for item in queryItems {
            params[item.name] = item.value
        }
        return params
    }
}

// MARK: - Preview

#Preview {
    LoginView()
}
