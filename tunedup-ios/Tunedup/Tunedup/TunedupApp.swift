import SwiftUI

@main
struct TunedUpApp: App {
    @StateObject private var authService = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authService)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root View
// Handles navigation between auth and main app flows

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showPinSetup = false

    var body: some View {
        Group {
            switch authService.authState {
            case .unknown:
                // Loading state
                ZStack {
                    TunedUpTheme.Colors.pureBlack
                        .ignoresSafeArea()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TunedUpTheme.Colors.cyan))
                        .scaleEffect(1.5)
                }

            case .unauthenticated, .awaitingCode:
                LoginView()

            case .awaitingPin:
                PinEntryView(mode: .verify) {
                    // PIN verified successfully
                }

            case .authenticated(let user):
                if !user.hasPin && showPinSetup {
                    PinEntryView(
                        mode: .set,
                        onSuccess: {
                            showPinSetup = false
                        },
                        onSkip: {
                            showPinSetup = false
                        }
                    )
                } else {
                    GarageView()
                        .onAppear {
                            // Check if we should prompt for PIN setup
                            if !user.hasPin {
                                showPinSetup = true
                            }
                        }
                }
            }
        }
        .animation(TunedUpTheme.Animation.spring, value: authService.authState)
    }
}
