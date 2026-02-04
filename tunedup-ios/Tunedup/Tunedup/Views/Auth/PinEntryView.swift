import SwiftUI

// MARK: - PIN Entry View
// 4-digit PIN for quick login

struct PinEntryView: View {
    enum Mode {
        case set
        case verify
    }

    let mode: Mode
    let onSuccess: () -> Void
    var onSkip: (() -> Void)? = nil

    @StateObject private var viewModel = AuthViewModel()
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var isConfirmStep: Bool = false
    @State private var shake: Bool = false

    var body: some View {
        ZStack {
            // Background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            VStack(spacing: TunedUpTheme.Spacing.xxl) {
                Spacer()

                // Header
                VStack(spacing: TunedUpTheme.Spacing.md) {
                    Image(systemName: mode == .set ? "lock.badge.plus" : "lock.fill")
                        .font(.system(size: 48))
                        .foregroundColor(TunedUpTheme.Colors.cyan)

                    Text(headerTitle)
                        .font(TunedUpTheme.Typography.title1)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(headerSubtitle)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // PIN dots
                PinDotsView(
                    enteredCount: isConfirmStep ? confirmPin.count : pin.count,
                    shake: shake
                )
                .padding(.vertical, TunedUpTheme.Spacing.xl)

                // Keypad
                PinKeypad(
                    pin: isConfirmStep ? $confirmPin : $pin,
                    onComplete: handlePinComplete
                )

                // Error
                if let error = viewModel.error {
                    Text(error)
                        .font(TunedUpTheme.Typography.footnote)
                        .foregroundColor(TunedUpTheme.Colors.error)
                        .padding(TunedUpTheme.Spacing.sm)
                        .background(TunedUpTheme.Colors.error.opacity(0.1))
                        .cornerRadius(TunedUpTheme.Radius.small)
                }

                Spacer()

                // Skip button (for set mode only)
                if mode == .set, let onSkip = onSkip {
                    Button(action: {
                        Haptics.impact(.light)
                        onSkip()
                    }) {
                        Text("Skip for now")
                    }
                    .buttonStyle(GhostButtonStyle())
                    .padding(.bottom, TunedUpTheme.Spacing.lg)
                }
            }
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
        }
    }

    // MARK: - Computed Properties

    private var headerTitle: String {
        switch mode {
        case .set:
            return isConfirmStep ? "Confirm PIN" : "Set Your PIN"
        case .verify:
            return "Enter PIN"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .set:
            return isConfirmStep
                ? "Enter the same PIN again"
                : "Create a 4-digit PIN for quick login"
        case .verify:
            return "Enter your 4-digit PIN"
        }
    }

    // MARK: - Actions

    private func handlePinComplete() {
        switch mode {
        case .set:
            if isConfirmStep {
                if confirmPin == pin {
                    // PINs match, save it
                    Task {
                        let success = await viewModel.setPin(confirmPin)
                        if success {
                            Haptics.notification(.success)
                            onSuccess()
                        } else {
                            triggerShake()
                        }
                    }
                } else {
                    // PINs don't match
                    viewModel.error = "PINs don't match. Try again."
                    triggerShake()
                    confirmPin = ""
                }
            } else {
                // Move to confirm step
                withAnimation(TunedUpTheme.Animation.spring) {
                    isConfirmStep = true
                }
            }

        case .verify:
            Task {
                let success = await viewModel.verifyPin(pin)
                if success {
                    Haptics.notification(.success)
                    onSuccess()
                } else {
                    triggerShake()
                    pin = ""
                }
            }
        }
    }

    private func triggerShake() {
        Haptics.notification(.error)
        withAnimation(.default) {
            shake = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
        }
    }
}

// MARK: - PIN Dots

struct PinDotsView: View {
    let enteredCount: Int
    let shake: Bool

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.lg) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(
                        index < enteredCount
                            ? TunedUpTheme.Colors.cyan
                            : TunedUpTheme.Colors.textTertiary.opacity(0.3)
                    )
                    .frame(width: 20, height: 20)
                    .scaleEffect(index < enteredCount ? 1.0 : 0.8)
                    .animation(TunedUpTheme.Animation.springFast, value: enteredCount)
            }
        }
        .offset(x: shake ? -10 : 0)
        .animation(
            shake
                ? Animation.default.repeatCount(3, autoreverses: true).speed(6)
                : .default,
            value: shake
        )
    }
}

// MARK: - PIN Keypad

struct PinKeypad: View {
    @Binding var pin: String
    let onComplete: () -> Void

    let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.md) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: TunedUpTheme.Spacing.md) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear
                                .frame(width: 80, height: 80)
                        } else {
                            PinKeyButton(key: key, onTap: {
                                handleKeyTap(key)
                            })
                        }
                    }
                }
            }
        }
    }

    private func handleKeyTap(_ key: String) {
        Haptics.impact(.light)

        if key == "⌫" {
            if !pin.isEmpty {
                pin.removeLast()
            }
        } else {
            if pin.count < 4 {
                pin.append(key)
                if pin.count == 4 {
                    // Slight delay before completion
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onComplete()
                    }
                }
            }
        }
    }
}

struct PinKeyButton: View {
    let key: String
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(isPressed ? TunedUpTheme.Colors.cardSurface : TunedUpTheme.Colors.darkSurface)
                    .frame(width: 80, height: 80)

                if key == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.system(size: 24))
                        .foregroundColor(TunedUpTheme.Colors.textSecondary)
                } else {
                    Text(key)
                        .font(TunedUpTheme.Typography.largeTitle)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Preview

#Preview("Set PIN") {
    PinEntryView(mode: .set, onSuccess: {}, onSkip: {})
}

#Preview("Verify PIN") {
    PinEntryView(mode: .verify, onSuccess: {})
}
