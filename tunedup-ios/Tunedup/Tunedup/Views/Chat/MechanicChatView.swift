import SwiftUI

// MARK: - Mechanic Chat View
// Chat UI with styled bubbles and typing indicators

struct MechanicChatView: View {
    let buildId: String

    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var showingNewChatConfirm = false

    var body: some View {
        ZStack {
            // Background
            TunedUpTheme.Colors.pureBlack
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ChatHeader(
                    onClose: { dismiss() },
                    onNewChat: { showingNewChatConfirm = true }
                )

                if viewModel.showContextWarning {
                    ContextWarningBanner(
                        onClose: { viewModel.dismissContextWarning() }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: TunedUpTheme.Spacing.md) {
                            // Welcome message
                            if viewModel.messages.isEmpty && !viewModel.isTyping {
                                WelcomeMessage()
                                    .padding(.top, TunedUpTheme.Spacing.xl)
                            }

                            // Messages
                            ForEach(viewModel.messages) { message in
                                ChatBubble(message: message)
                                    .id(message.id)
                            }

                            // Typing indicator
                            if viewModel.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }

                            // Error message
                            if let error = viewModel.error {
                                ChatErrorBubble(message: error)
                                    .id("error")
                            }
                        }
                        .padding(.horizontal, TunedUpTheme.Spacing.lg)
                        .padding(.vertical, TunedUpTheme.Spacing.md)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isTyping) { _, isTyping in
                        if isTyping {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.error) { _, newError in
                        if newError != nil {
                            withAnimation {
                                proxy.scrollTo("error", anchor: .bottom)
                            }
                        }
                    }
                }

                // Input area
                ChatInputArea(
                    text: $viewModel.inputText,
                    isFocused: $isInputFocused,
                    isLoading: viewModel.isTyping,
                    characterLimit: ChatConstants.maxMessageLength,
                    onSend: {
                        Task {
                            await viewModel.sendMessage(buildId: buildId)
                        }
                    }
                )
            }
        }
        .onTapGesture {
            isInputFocused = false
        }
        .task {
            await viewModel.loadHistory(buildId: buildId)
        }
        .alert("Start a new chat?", isPresented: $showingNewChatConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("New Chat", role: .destructive) {
                Task { await viewModel.resetChat(buildId: buildId) }
            }
        } message: {
            Text("This will clear the chat history for this build.")
        }
    }
}

// MARK: - Chat Header

struct ChatHeader: View {
    let onClose: () -> Void
    let onNewChat: () -> Void

    var body: some View {
        HStack {
            Button(action: {
                Haptics.impact(.light)
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Mechanic")
                    .font(TunedUpTheme.Typography.bodyBold)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text("Online")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.success)
            }

            Spacer()

            // Mechanic avatar
            HStack(spacing: TunedUpTheme.Spacing.xs) {
                Button(action: {
                    Haptics.impact(.light)
                    onNewChat()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("New Chat")
                    }
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .padding(.horizontal, TunedUpTheme.Spacing.sm)
                    .padding(.vertical, TunedUpTheme.Spacing.xs)
                    .background(TunedUpTheme.Colors.cardSurface)
                    .cornerRadius(TunedUpTheme.Radius.pill)
                }

                ZStack {
                    Circle()
                        .fill(TunedUpTheme.Colors.cyan.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 18))
                        .foregroundColor(TunedUpTheme.Colors.cyan)
                }
            }
        }
        .padding(.horizontal, TunedUpTheme.Spacing.md)
        .padding(.vertical, TunedUpTheme.Spacing.sm)
        .background(TunedUpTheme.Colors.darkSurface)
    }
}

// MARK: - Welcome Message

struct WelcomeMessage: View {
    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // Mechanic avatar
            ZStack {
                Circle()
                    .fill(TunedUpTheme.Colors.cyan.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 32))
                    .foregroundColor(TunedUpTheme.Colors.cyan)
            }

            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("Hey there!")
                    .font(TunedUpTheme.Typography.title2)
                    .foregroundColor(TunedUpTheme.Colors.textPrimary)

                Text("I'm your personal mechanic assistant. Ask me anything about your build - parts compatibility, installation tips, or whether that eBay turbo is actually worth it (spoiler: probably not).")
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Quick prompts
            VStack(spacing: TunedUpTheme.Spacing.sm) {
                Text("Quick questions:")
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)

                QuickPromptGrid()
            }
        }
        .padding(TunedUpTheme.Spacing.lg)
    }
}

struct QuickPromptGrid: View {
    let prompts = [
        "What should I do first?",
        "Is this build streetable?",
        "What tools do I need?",
        "Can I DIY the tune?"
    ]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: TunedUpTheme.Spacing.sm) {
            ForEach(prompts, id: \.self) { prompt in
                QuickPromptButton(text: prompt)
            }
        }
    }
}

struct QuickPromptButton: View {
    let text: String

    var body: some View {
        Button(action: {
            Haptics.impact(.light)
            // TODO: Fill input with prompt
        }) {
            Text(text)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
                .padding(.horizontal, TunedUpTheme.Spacing.sm)
                .padding(.vertical, TunedUpTheme.Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.small)
                .overlay(
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.small)
                        .stroke(TunedUpTheme.Colors.textTertiary.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: TunedUpTheme.Spacing.sm) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                // Mechanic avatar
                ZStack {
                    Circle()
                        .fill(TunedUpTheme.Colors.magenta.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Image(systemName: "wrench.and.screwdriver")
                        .font(.system(size: 14))
                        .foregroundColor(TunedUpTheme.Colors.magenta)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: TunedUpTheme.Spacing.xs) {
                // Message content
                Group {
                    if isUser {
                        Text(message.content)
                    } else {
                        MarkdownText(message.content)
                    }
                }
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(isUser ? TunedUpTheme.Colors.pureBlack : TunedUpTheme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TunedUpTheme.Spacing.md)
                .padding(.vertical, TunedUpTheme.Spacing.sm)
                .background(
                    isUser
                        ? TunedUpTheme.Colors.cyan
                        : TunedUpTheme.Colors.cardSurface
                )
                .cornerRadius(TunedUpTheme.Radius.medium)
                .if(!isUser) { view in
                    view.overlay(
                        RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                            .stroke(TunedUpTheme.Colors.magenta.opacity(0.3), lineWidth: 1)
                    )
                }

                // Timestamp
                Text(message.createdAt.relativeFormatted)
                    .font(TunedUpTheme.Typography.caption)
                    .foregroundColor(TunedUpTheme.Colors.textTertiary)
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Markdown Text

struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
        ) {
            Text(attributed)
        } else {
            Text(text)
        }
    }
}

// MARK: - Error Bubble

struct ChatErrorBubble: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(TunedUpTheme.Colors.error)

            Text(message)
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TunedUpTheme.Spacing.md)
        .padding(.vertical, TunedUpTheme.Spacing.sm)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.error.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Context Warning Banner

struct ContextWarningBanner: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: TunedUpTheme.Spacing.sm) {
            Image(systemName: "fuelpump.fill")
                .foregroundColor(TunedUpTheme.Colors.cyan)

            Text("You pumped in a lot of ethanol and I haven't upgraded my fuel injectors (context window near limit).")
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.textPrimary)
                .lineLimit(2)

            Spacer()

            Button(action: {
                Haptics.impact(.light)
                onClose()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, TunedUpTheme.Spacing.md)
        .padding(.vertical, TunedUpTheme.Spacing.sm)
        .background(
            LinearGradient(
                colors: [
                    TunedUpTheme.Colors.cyan.opacity(0.15),
                    TunedUpTheme.Colors.cardSurface
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.cyan.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(TunedUpTheme.Radius.medium)
        .padding(.horizontal, TunedUpTheme.Spacing.lg)
        .padding(.vertical, TunedUpTheme.Spacing.sm)
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotAnimations = [false, false, false]

    var body: some View {
        HStack(alignment: .bottom, spacing: TunedUpTheme.Spacing.sm) {
            // Mechanic avatar
            ZStack {
                Circle()
                    .fill(TunedUpTheme.Colors.magenta.opacity(0.2))
                    .frame(width: 32, height: 32)

                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 14))
                    .foregroundColor(TunedUpTheme.Colors.magenta)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(TunedUpTheme.Colors.textSecondary)
                        .frame(width: 8, height: 8)
                        .offset(y: dotAnimations[index] ? -4 : 0)
                }
            }
            .padding(.horizontal, TunedUpTheme.Spacing.md)
            .padding(.vertical, TunedUpTheme.Spacing.sm)
            .background(TunedUpTheme.Colors.cardSurface)
            .cornerRadius(TunedUpTheme.Radius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                    .stroke(TunedUpTheme.Colors.magenta.opacity(0.3), lineWidth: 1)
            )

            Spacer(minLength: 60)
        }
        .onAppear {
            animateDots()
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            withAnimation(
                Animation.easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(Double(i) * 0.15)
            ) {
                dotAnimations[i] = true
            }
        }
    }
}

// MARK: - Chat Input Area

struct ChatInputArea: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let isLoading: Bool
    let characterLimit: Int
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(TunedUpTheme.Colors.textTertiary.opacity(0.2))

            HStack(alignment: .bottom, spacing: TunedUpTheme.Spacing.sm) {
                // Text input
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Ask the mechanic...")
                            .font(TunedUpTheme.Typography.body)
                            .foregroundColor(TunedUpTheme.Colors.textTertiary)
                            .padding(.horizontal, TunedUpTheme.Spacing.md)
                            .padding(.vertical, TunedUpTheme.Spacing.sm + 8)
                    }

                    TextEditor(text: $text)
                        .font(TunedUpTheme.Typography.body)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                        .padding(.horizontal, TunedUpTheme.Spacing.sm)
                        .padding(.vertical, TunedUpTheme.Spacing.xs)
                        .frame(minHeight: 44, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .focused(isFocused)
                }
                .background(TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                        .stroke(
                            isFocused.wrappedValue
                                ? TunedUpTheme.Colors.cyan.opacity(0.5)
                                : TunedUpTheme.Colors.textTertiary.opacity(0.2),
                            lineWidth: 1
                        )
                )

                // Send button
                Button(action: {
                    Haptics.impact(.medium)
                    onSend()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                text.isEmpty || isLoading
                                    ? TunedUpTheme.Colors.textTertiary
                                    : TunedUpTheme.Colors.cyan
                            )
                            .frame(width: 44, height: 44)

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(
                                    text.isEmpty
                                        ? TunedUpTheme.Colors.textSecondary
                                        : TunedUpTheme.Colors.pureBlack
                                )
                        }
                    }
                }
                .disabled(text.isEmpty || isLoading)
            }
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.vertical, TunedUpTheme.Spacing.md)

            // Character count
            if !text.isEmpty {
                HStack {
                    Spacer()
                    Text("\(text.count)/\(characterLimit)")
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(
                            text.count > characterLimit
                                ? TunedUpTheme.Colors.error
                                : TunedUpTheme.Colors.textTertiary
                        )
                }
                .padding(.horizontal, TunedUpTheme.Spacing.lg)
                .padding(.bottom, TunedUpTheme.Spacing.sm)
            }
        }
        .background(TunedUpTheme.Colors.darkSurface)
    }
}

// MARK: - Preview

#Preview {
    MechanicChatView(buildId: "test-id")
}
