# TunedUp Feature Implementation Plan

> Created: 2026-02-09
> Status: Planning

This document outlines the implementation plan for the following features:
1. **Build Sharing** - Generate shareable links for builds
2. **Ask the Mechanic (Global)** - Chat without selecting a build first
3. **Build Tracker** - "Let's Build This" checklist with install guides

Also includes:
- Switch chat from Gemini Flash to Gemini Pro
- Remove location step from wizard

---

## Table of Contents

1. [Quick Wins (Pre-Feature)](#quick-wins)
2. [Feature 1: Build Sharing](#feature-1-build-sharing)
3. [Feature 2: Ask the Mechanic (Global)](#feature-2-ask-the-mechanic-global)
4. [Feature 3: Build Tracker with Install Guides](#feature-3-build-tracker-with-install-guides)
5. [Implementation Order](#implementation-order)

---

## Quick Wins

### A. Switch Chat to Gemini Pro

**Current State:** Chat uses `getFlashModel()` which returns `gemini-2.5-flash`

**Change:** Use Pro model for chat to get better quality responses

**Files to Modify:**
- `tunedup-backend/src/lib/gemini.ts`

**Implementation:**

```typescript
// In gemini.ts, modify callChat function

// Add new function for Pro chat
function getProModelForChat(): GenerativeModel {
  return genAI.getGenerativeModel({
    model: PRO_MODEL,
    generationConfig: chatConfig, // Keep the chat config (more creative)
  });
}

// In callChat function, change:
// const model = getFlashModel();
// To:
const model = getProModelForChat();
```

**Estimated Time:** 5 minutes

---

### B. Remove Location Step from Wizard

**Current State:** 6-step wizard with Location as step 6

**Change:** Remove location step entirely (5 steps: Vehicle, Budget, Goals, Preferences, Mods)

**Files to Modify:**
- `tunedup-ios/Tunedup/Tunedup/Views/Wizard/NewBuildWizardView.swift`
- `tunedup-ios/Tunedup/Tunedup/ViewModels/WizardViewModel.swift`

**Implementation:**

1. **WizardStep enum** - Remove `.location` case
```swift
enum WizardStep: Int, CaseIterable {
    case vehicle = 0
    case budget
    case goals
    case preferences
    case mods  // This becomes the last step
    // REMOVE: case location
}
```

2. **WizardStepContent** - Remove `.location` switch case

3. **NewBuildWizardView** - Change condition for Generate button:
```swift
// Change from:
if viewModel.currentStep == .location {
// To:
if viewModel.currentStep == .mods {
```

4. **WizardViewModel** - Remove city property if not used elsewhere

5. **Remove `LocationStepContent` struct entirely**

**Estimated Time:** 15 minutes

---

## Feature 1: Build Sharing

### Overview

Allow users to generate a shareable link for their build that anyone can view (read-only, no account required).

### User Flow

1. User taps "Share" button on build detail screen
2. System generates a unique share token and URL
3. User can copy link or open system share sheet
4. Anyone with link can view the build (no auth required)
5. Viewer sees build details but cannot chat or modify

### Data Model Changes

**New Table: `shared_builds`**

```prisma
model SharedBuild {
  id        String   @id @default(cuid())
  buildId   String
  token     String   @unique  // Random 16-char alphanumeric
  createdAt DateTime @default(now())
  expiresAt DateTime?  // Optional expiration
  viewCount Int      @default(0)

  build     Build    @relation(fields: [buildId], references: [id], onDelete: Cascade)

  @@index([token])
  @@index([buildId])
  @@map("shared_builds")
}
```

**Add to Build model:**
```prisma
model Build {
  // ... existing fields
  sharedLinks SharedBuild[]
}
```

### API Endpoints

#### POST /api/builds/:id/share
Create a share link for a build.

```typescript
// Request: none (uses auth)
// Response 200:
{
  shareUrl: "https://tunedup.dev/s/abc123xyz789",
  token: "abc123xyz789",
  expiresAt: null
}
```

#### GET /api/shared/:token
Get shared build data (no auth required).

```typescript
// Response 200:
{
  build: {
    vehicle: {...},
    plan: {...},
    performance: {...},
    presentation: {...},
    // Note: NO user info, NO chat access
  },
  createdAt: "2026-02-09T...",
  ownerName: null  // Privacy - don't expose owner
}
```

#### DELETE /api/builds/:id/share/:token
Revoke a share link (auth required, owner only).

### iOS Implementation

#### New Files:
- `Views/Shared/SharedBuildView.swift` - Read-only build view for shared links
- `Services/DeepLinkHandler.swift` - Handle `tunedup.dev/s/` URLs

#### Modified Files:
- `BuildDetailView.swift` - Add share button in header
- `TunedUpApp.swift` - Register URL scheme handler

#### Share Button UI:
```swift
// In BuildDetailHeader, add share button next to delete:
Button(action: { onShare() }) {
    Image(systemName: "square.and.arrow.up")
        .font(.system(size: 18))
        .foregroundColor(TunedUpTheme.Colors.textTertiary)
        .frame(width: 44, height: 44)
}
```

#### Share Sheet:
```swift
struct ShareSheet: View {
    let shareUrl: String
    @State private var showingShareSheet = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: TunedUpTheme.Spacing.lg) {
            // URL display
            Text(shareUrl)
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.cyan)
                .padding()
                .background(TunedUpTheme.Colors.cardSurface)
                .cornerRadius(TunedUpTheme.Radius.medium)

            HStack(spacing: TunedUpTheme.Spacing.md) {
                // Copy button
                Button("Copy Link") {
                    UIPasteboard.general.string = shareUrl
                    copied = true
                }
                .buttonStyle(SecondaryButtonStyle())

                // Share button
                Button("Share") {
                    showingShareSheet = true
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareActivityView(items: [URL(string: shareUrl)!])
        }
    }
}
```

#### SharedBuildView (Read-Only):
- Reuse most of `BuildDetailView` components
- Remove: Chat button, Delete button, any edit functionality
- Add: "Get TunedUp" CTA at bottom for viewers without the app
- Add: "This build was shared with you" banner at top

### Web Fallback (Optional, Later)

If user opens share link in browser without app:
- Simple web page showing build summary
- "Download TunedUp on iOS" CTA
- Could be a simple Next.js page at `/s/[token]`

### Implementation Tasks

1. [ ] Add Prisma migration for `shared_builds` table
2. [ ] Implement `POST /api/builds/:id/share` endpoint
3. [ ] Implement `GET /api/shared/:token` endpoint
4. [ ] Implement `DELETE /api/builds/:id/share/:token` endpoint
5. [ ] Add share button to `BuildDetailHeader`
6. [ ] Create `ShareSheet` component
7. [ ] Create `SharedBuildView` for viewing shared builds
8. [ ] Add deep link handling in `TunedUpApp`
9. [ ] (Optional) Add web fallback page

**Estimated Time:** 4-6 hours

---

## Feature 2: Ask the Mechanic (Global)

### Overview

Add a floating "Ask Mechanic" button on the Garage screen that opens a general chat without build context. This lets users ask car questions before creating a build.

### User Flow

1. User sees "Ask Mechanic" button on Garage screen (always visible)
2. Tap opens full-screen chat (similar to build chat)
3. Chat has no build context - general car knowledge
4. System prompt focuses on general car advice, can suggest creating a build

### Data Model Changes

**Modify ChatThread model:**
```prisma
model ChatThread {
  id        String   @id @default(cuid())
  userId    String
  buildId   String?  // NOW NULLABLE - null means global chat
  createdAt DateTime @default(now())

  build     Build?   @relation(fields: [buildId], references: [id], onDelete: Cascade)
  messages  ChatMessage[]

  @@index([buildId])
  @@index([userId])
  @@map("chat_threads")
}
```

### API Changes

**Modify POST /api/chat:**
- Make `buildId` optional in request schema
- If no buildId, use global chat system prompt
- Create/use a "global" thread per user

```typescript
// In validation.ts, update schema:
export const chatSchema = z.object({
  buildId: z.string().optional(), // Now optional
  message: z.string().min(1).max(500),
});
```

**Modify chat.ts service:**
```typescript
// New global system prompt
function getGlobalSystemPrompt(): string {
  return `You are a friendly shop mechanic with wicked humor helping someone with general car questions.

YOUR PERSONALITY:
- Friendly shop mechanic with wicked humor
- Accurate and safe advice, delivered with personality
- Keep responses CONCISE - under 300 words
- Be helpful but don't over-explain
- Use casual language but stay professional

CAPABILITIES:
- Answer general car maintenance questions
- Explain car modification concepts
- Help users understand what mods might suit their goals
- Recommend when someone should create a build plan for detailed advice

RULES:
- NEVER recommend unsafe modifications without warnings
- NEVER suggest skipping safety equipment
- If someone asks about a specific build, suggest they create a build plan in the app for detailed, personalized advice
- Keep responses SHORT and punchy - no essays`;
}

// Modify processChat to handle null buildId
export async function processChat(
  userId: string,
  buildId: string | null,
  userMessage: string
): Promise<...> {
  // Get or create thread (buildId can be null for global)
  let thread = await prisma.chatThread.findFirst({
    where: { userId, buildId: buildId }, // buildId: null matches global
    ...
  });

  // Use appropriate system prompt
  const systemPrompt = buildId
    ? buildSystemPromptFromBuild(build)
    : getGlobalSystemPrompt();

  // Rest of logic unchanged
}
```

### iOS Implementation

#### Modified Files:
- `GarageView.swift` - Add floating Ask Mechanic button
- `MechanicChatView.swift` - Handle optional buildId
- `ChatViewModel.swift` - Support null buildId
- `APIClient.swift` - Update chat endpoint to make buildId optional

#### GarageView Changes:

```swift
struct GarageView: View {
    // ... existing state
    @State private var showingGlobalChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                // ... existing content

                // Floating Ask Mechanic button (always visible)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        GlobalChatButton(onTap: { showingGlobalChat = true })
                    }
                    .padding(.trailing, TunedUpTheme.Spacing.lg)
                    .padding(.bottom, TunedUpTheme.Spacing.xl)
                }
            }
            // ... existing modifiers
            .sheet(isPresented: $showingGlobalChat) {
                MechanicChatView(buildId: nil) // nil = global chat
            }
        }
    }
}

struct GlobalChatButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            Haptics.impact(.medium)
            onTap()
        }) {
            HStack(spacing: TunedUpTheme.Spacing.sm) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 18))
                Text("Ask Mechanic")
                    .font(TunedUpTheme.Typography.buttonSmall)
            }
            .foregroundColor(TunedUpTheme.Colors.pureBlack)
            .padding(.horizontal, TunedUpTheme.Spacing.md)
            .padding(.vertical, TunedUpTheme.Spacing.sm)
            .background(TunedUpTheme.Colors.magenta)
            .cornerRadius(TunedUpTheme.Radius.pill)
            .shadow(color: TunedUpTheme.Colors.magenta.opacity(0.4), radius: 12, y: 4)
        }
    }
}
```

#### MechanicChatView Changes:

```swift
struct MechanicChatView: View {
    let buildId: String?  // Now optional

    // Update welcome message based on context
    struct WelcomeMessage: View {
        let hasBuild: Bool

        var body: some View {
            VStack(spacing: TunedUpTheme.Spacing.lg) {
                // ... avatar

                VStack(spacing: TunedUpTheme.Spacing.sm) {
                    Text("Hey there!")
                        .font(TunedUpTheme.Typography.title2)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)

                    Text(hasBuild
                        ? "I'm your personal mechanic assistant. Ask me anything about your build..."
                        : "I'm your personal mechanic assistant. Ask me anything about cars - maintenance tips, mod ideas, or what to do with that weird noise your engine's making."
                    )
                    .font(TunedUpTheme.Typography.body)
                    .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                }

                // Different quick prompts for global vs build chat
                QuickPromptGrid(hasBuild: hasBuild)
            }
        }
    }
}
```

#### ChatViewModel Changes:

```swift
class ChatViewModel: ObservableObject {
    // ... existing properties

    func loadHistory(buildId: String?) async {
        // Handle nil buildId
        let endpoint = buildId != nil
            ? "/api/chat?buildId=\(buildId!)"
            : "/api/chat"  // Global endpoint
        // ...
    }

    func sendMessage(buildId: String?) async {
        // buildId can be nil for global chat
        // ...
    }
}
```

### Implementation Tasks

1. [ ] Add Prisma migration to make `buildId` nullable on `chat_threads`
2. [ ] Update validation schema to make `buildId` optional
3. [ ] Add global system prompt to `chat.ts`
4. [ ] Modify `processChat` to handle null buildId
5. [ ] Update `GET /api/chat` to support global threads
6. [ ] Add `GlobalChatButton` to `GarageView`
7. [ ] Update `MechanicChatView` to accept optional buildId
8. [ ] Update `ChatViewModel` for optional buildId
9. [ ] Update welcome message and quick prompts for global context

**Estimated Time:** 3-4 hours

---

## Feature 3: Build Tracker with Install Guides

### Overview

Add a "Let's Build This" mode that converts the build plan into an interactive checklist. Each part has:
- Checkbox to mark as purchased/installed
- "How to Install" button that generates an AI install guide on-demand

### User Flow

1. User views build detail, taps "Let's Build This" button at bottom
2. Opens Build Tracker view with all mods as checkable items
3. Each item shows: name, cost, DIY/Shop badge
4. Tap "How to Install" → AI generates install guide specific to that car + part
5. If mod is marked "Pro Install" → Guide says "Here's the deal, you really should have a shop do this because [reasons]"
6. User can mark items as done, progress is persisted

### Data Model Changes

**New Table: `build_progress`**

```prisma
model BuildProgress {
  id          String   @id @default(cuid())
  buildId     String
  modId       String   // References mod ID from planJson
  status      String   @default("pending")  // pending, purchased, installed
  purchasedAt DateTime?
  installedAt DateTime?
  notes       String?  // User notes

  build       Build    @relation(fields: [buildId], references: [id], onDelete: Cascade)

  @@unique([buildId, modId])
  @@index([buildId])
  @@map("build_progress")
}
```

**Add to Build model:**
```prisma
model Build {
  // ... existing fields
  progress BuildProgress[]
}
```

### API Endpoints

#### GET /api/builds/:id/progress
Get progress for all mods in a build.

```typescript
// Response 200:
{
  progress: [
    {
      modId: "intake-1",
      status: "installed",
      purchasedAt: "2026-02-01T...",
      installedAt: "2026-02-05T...",
      notes: "Got it from Summit Racing"
    },
    // ...
  ],
  stats: {
    total: 12,
    purchased: 5,
    installed: 3
  }
}
```

#### PATCH /api/builds/:id/progress/:modId
Update progress for a specific mod.

```typescript
// Request:
{
  status: "purchased" | "installed" | "pending",
  notes?: string
}

// Response 200:
{
  modId: "intake-1",
  status: "purchased",
  purchasedAt: "2026-02-09T...",
  installedAt: null,
  notes: "Ordered from Amazon"
}
```

#### POST /api/builds/:id/install-guide
Generate an install guide for a specific mod (AI-powered).

```typescript
// Request:
{
  modId: string
}

// Response 200:
{
  guide: {
    title: "Installing a Cold Air Intake on your 2019 Honda Civic Si",
    recommendation: "diy" | "shop",
    shopReason?: string,  // If shop recommended
    difficulty: 2,
    timeEstimate: "1-2 hours",
    tools: ["10mm socket", "flathead screwdriver", ...],
    steps: [
      {
        number: 1,
        title: "Disconnect the battery",
        description: "Always start by disconnecting...",
        warning?: "Don't skip this or you might..."
      },
      // ...
    ],
    tips: ["Pro tip: Take a photo before...", ...],
    warnings: ["Don't tighten the clamp too much or...", ...]
  },
  tokensUsed: 1234
}
```

### Install Guide AI Prompt

```typescript
const installGuideSystemPrompt = `You are a friendly shop mechanic creating an install guide. Be helpful, accurate, and include safety warnings.

VEHICLE: {{year}} {{make}} {{model}} {{trim}}
MODIFICATION: {{modName}} ({{modCategory}})
DIY RECOMMENDED: {{diyable}}
DIFFICULTY: {{difficulty}}/5

IF THIS IS A SHOP-RECOMMENDED INSTALL:
Start by being honest: "Look, I could walk you through this, but here's the deal..." and explain why a shop is recommended. Then still provide general information about what's involved so they understand what they're paying for.

IF THIS IS DIY-FRIENDLY:
Provide a clear step-by-step guide with:
- Required tools
- Time estimate
- Numbered steps with clear descriptions
- Safety warnings where relevant
- Pro tips from experience

TONE:
- Friendly mechanic voice
- Clear and concise
- Don't assume expertise
- Include "gotchas" that catch beginners

OUTPUT FORMAT:
Return valid JSON matching the InstallGuide schema.`;
```

### iOS Implementation

#### New Files:
- `Views/BuildTracker/BuildTrackerView.swift` - Main tracker view
- `Views/BuildTracker/ModProgressCard.swift` - Individual mod card with checkbox
- `Views/BuildTracker/InstallGuideView.swift` - Display generated guide
- `ViewModels/BuildTrackerViewModel.swift` - State management
- `Models/BuildProgress.swift` - Progress models

#### BuildTrackerView:

```swift
struct BuildTrackerView: View {
    let build: Build
    @StateObject private var viewModel = BuildTrackerViewModel()
    @State private var selectedModForGuide: Mod?

    var body: some View {
        ZStack {
            TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

            ScrollView {
                VStack(spacing: TunedUpTheme.Spacing.lg) {
                    // Progress summary
                    ProgressSummaryCard(stats: viewModel.stats)

                    // Stage sections
                    ForEach(build.plan?.stages ?? []) { stage in
                        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
                            Text("STAGE \(stage.stageNumber): \(stage.name)")
                                .font(TunedUpTheme.Typography.caption)
                                .foregroundColor(TunedUpTheme.Colors.textTertiary)
                                .tracking(1)

                            ForEach(stage.mods) { mod in
                                ModProgressCard(
                                    mod: mod,
                                    execution: build.execution?.modExecutions.first { $0.modId == mod.id },
                                    progress: viewModel.progress[mod.id],
                                    onStatusChange: { status in
                                        Task { await viewModel.updateProgress(modId: mod.id, status: status) }
                                    },
                                    onInstallGuideTap: {
                                        selectedModForGuide = mod
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(TunedUpTheme.Spacing.lg)
            }
        }
        .sheet(item: $selectedModForGuide) { mod in
            InstallGuideSheet(
                build: build,
                mod: mod,
                execution: build.execution?.modExecutions.first { $0.modId == mod.id }
            )
        }
        .task {
            await viewModel.loadProgress(buildId: build.id)
        }
    }
}
```

#### ModProgressCard:

```swift
struct ModProgressCard: View {
    let mod: Mod
    let execution: ModExecution?
    let progress: ModProgress?
    let onStatusChange: (String) -> Void
    let onInstallGuideTap: () -> Void

    private var isShopRecommended: Bool {
        execution?.diyable == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.md) {
            // Header row
            HStack {
                // Checkbox
                ProgressCheckbox(
                    status: progress?.status ?? "pending",
                    onChange: onStatusChange
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(mod.name)
                        .font(TunedUpTheme.Typography.bodyBold)
                        .foregroundColor(TunedUpTheme.Colors.textPrimary)
                        .strikethrough(progress?.status == "installed")

                    Text(mod.estimatedCost.formatted)
                        .font(TunedUpTheme.Typography.caption)
                        .foregroundColor(TunedUpTheme.Colors.cyan)
                }

                Spacer()

                // DIY/Shop badge
                if let exec = execution {
                    DIYBadge(diyable: exec.diyable, difficulty: exec.difficulty)
                }
            }

            // Install guide button
            Button(action: onInstallGuideTap) {
                HStack {
                    Image(systemName: "book.fill")
                    Text("How to Install")
                    if isShopRecommended {
                        Text("(Shop Recommended)")
                            .foregroundColor(TunedUpTheme.Colors.warning)
                    }
                }
                .font(TunedUpTheme.Typography.caption)
                .foregroundColor(TunedUpTheme.Colors.cyan)
            }
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.cardSurface)
        .cornerRadius(TunedUpTheme.Radius.medium)
    }
}

struct ProgressCheckbox: View {
    let status: String
    let onChange: (String) -> Void

    var body: some View {
        Menu {
            Button("Not Started") { onChange("pending") }
            Button("Purchased") { onChange("purchased") }
            Button("Installed") { onChange("installed") }
        } label: {
            ZStack {
                Circle()
                    .stroke(statusColor, lineWidth: 2)
                    .frame(width: 28, height: 28)

                if status == "installed" {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(TunedUpTheme.Colors.success)
                }
                else if status == "purchased" {
                    Circle()
                        .fill(TunedUpTheme.Colors.warning)
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private var statusColor: Color {
        switch status {
        case "installed": return TunedUpTheme.Colors.success
        case "purchased": return TunedUpTheme.Colors.warning
        default: return TunedUpTheme.Colors.textTertiary
        }
    }
}
```

#### InstallGuideSheet:

```swift
struct InstallGuideSheet: View {
    let build: Build
    let mod: Mod
    let execution: ModExecution?

    @StateObject private var viewModel = InstallGuideViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                TunedUpTheme.Colors.pureBlack.ignoresSafeArea()

                if viewModel.isLoading {
                    VStack(spacing: TunedUpTheme.Spacing.lg) {
                        ProgressView()
                        Text("Generating install guide...")
                            .font(TunedUpTheme.Typography.body)
                            .foregroundColor(TunedUpTheme.Colors.textSecondary)
                    }
                } else if let guide = viewModel.guide {
                    ScrollView {
                        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.lg) {
                            // Title
                            Text(guide.title)
                                .font(TunedUpTheme.Typography.title2)
                                .foregroundColor(TunedUpTheme.Colors.textPrimary)

                            // Shop recommendation warning
                            if guide.recommendation == "shop" {
                                ShopRecommendationBanner(reason: guide.shopReason)
                            }

                            // Quick stats
                            HStack(spacing: TunedUpTheme.Spacing.lg) {
                                StatPill(icon: "clock", text: guide.timeEstimate)
                                StatPill(icon: "wrench", text: "Difficulty \(guide.difficulty)/5")
                            }

                            // Tools needed
                            ToolsSection(tools: guide.tools)

                            // Steps
                            StepsSection(steps: guide.steps)

                            // Tips
                            if !guide.tips.isEmpty {
                                TipsSection(tips: guide.tips)
                            }

                            // Warnings
                            if !guide.warnings.isEmpty {
                                WarningsSection(warnings: guide.warnings)
                            }
                        }
                        .padding(TunedUpTheme.Spacing.lg)
                    }
                } else if let error = viewModel.error {
                    ErrorView(message: error, onRetry: {
                        Task { await viewModel.generateGuide(buildId: build.id, modId: mod.id) }
                    })
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await viewModel.generateGuide(buildId: build.id, modId: mod.id)
        }
    }
}

struct ShopRecommendationBanner: View {
    let reason: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TunedUpTheme.Spacing.sm) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                Text("Shop Recommended")
                    .font(TunedUpTheme.Typography.bodyBold)
            }
            .foregroundColor(TunedUpTheme.Colors.warning)

            Text(reason ?? "This install requires specialized equipment or expertise that's typically only found at a shop.")
                .font(TunedUpTheme.Typography.body)
                .foregroundColor(TunedUpTheme.Colors.textSecondary)
        }
        .padding(TunedUpTheme.Spacing.md)
        .background(TunedUpTheme.Colors.warning.opacity(0.1))
        .cornerRadius(TunedUpTheme.Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: TunedUpTheme.Radius.medium)
                .stroke(TunedUpTheme.Colors.warning.opacity(0.3), lineWidth: 1)
        )
    }
}
```

#### Entry Point (BuildDetailView):

```swift
// Add to bottom of BuildDetailView, below the chat button
VStack {
    Spacer()
    VStack(spacing: TunedUpTheme.Spacing.md) {
        // Existing chat button
        ChatFloatingButton(onTap: { showingChat = true })

        // New "Let's Build This" button
        Button(action: { showingTracker = true }) {
            HStack(spacing: TunedUpTheme.Spacing.sm) {
                Image(systemName: "checklist")
                    .font(.system(size: 20))
                Text("Let's Build This")
                    .font(TunedUpTheme.Typography.button)
            }
            .foregroundColor(TunedUpTheme.Colors.cyan)
            .padding(.horizontal, TunedUpTheme.Spacing.lg)
            .padding(.vertical, TunedUpTheme.Spacing.md)
            .background(TunedUpTheme.Colors.cardSurface)
            .cornerRadius(TunedUpTheme.Radius.pill)
            .overlay(
                RoundedRectangle(cornerRadius: TunedUpTheme.Radius.pill)
                    .stroke(TunedUpTheme.Colors.cyan, lineWidth: 2)
            )
        }
    }
    .padding(.bottom, TunedUpTheme.Spacing.xl)
}
.fullScreenCover(isPresented: $showingTracker) {
    BuildTrackerView(build: build)
}
```

### Implementation Tasks

1. [ ] Add Prisma migration for `build_progress` table
2. [ ] Implement `GET /api/builds/:id/progress` endpoint
3. [ ] Implement `PATCH /api/builds/:id/progress/:modId` endpoint
4. [ ] Implement `POST /api/builds/:id/install-guide` endpoint
5. [ ] Create install guide AI prompt and Gemini call
6. [ ] Create `BuildProgress.swift` models
7. [ ] Create `BuildTrackerViewModel.swift`
8. [ ] Create `BuildTrackerView.swift`
9. [ ] Create `ModProgressCard.swift` with checkbox
10. [ ] Create `InstallGuideSheet.swift`
11. [ ] Create `InstallGuideViewModel.swift`
12. [ ] Add "Let's Build This" button to `BuildDetailView`
13. [ ] Test install guide generation for both DIY and shop-recommended mods

**Estimated Time:** 8-12 hours

---

## Implementation Order

### Phase 1: Quick Wins (Day 1)
1. Switch chat to Gemini Pro *(5 min)*
2. Remove location step from wizard *(15 min)*

### Phase 2: Global Chat (Day 1-2)
3. Make buildId nullable in chat API *(1 hr)*
4. Add global system prompt *(30 min)*
5. Add Ask Mechanic button to Garage *(1 hr)*
6. Update MechanicChatView for optional buildId *(1 hr)*

### Phase 3: Build Sharing (Day 2-3)
7. Create shared_builds table and API *(2 hr)*
8. Add share button and sheet to iOS *(2 hr)*
9. Create SharedBuildView *(2 hr)*
10. Add deep link handling *(1 hr)*

### Phase 4: Build Tracker (Day 3-5)
11. Create build_progress table and API *(2 hr)*
12. Create install guide API endpoint *(2 hr)*
13. Build iOS tracker UI *(4 hr)*
14. Build install guide UI *(3 hr)*

### Total Estimated Time: 4-5 days

---

## Notes

- All AI-generated content should include appropriate disclaimers
- Install guides should be cached (same mod + car = same guide) to reduce API costs
- Progress data should sync automatically when app opens
- Consider adding push notifications for "next step" reminders (v2)
