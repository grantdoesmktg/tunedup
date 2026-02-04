# TunedUp iOS

SwiftUI iOS app for TunedUp - AI-powered car modification build planner.

## Requirements

- Xcode 15+
- iOS 17+
- Swift 5.9+

## Setup

1. Open `TunedUp.xcodeproj` in Xcode
2. Update the API base URL in `Services/APIClient.swift` if needed
3. Build and run on simulator or device

## Project Structure

```
TunedUp/
├── TunedUpApp.swift          # App entry point
├── Models/
│   ├── User.swift            # Auth models
│   ├── Build.swift           # Build & pipeline models
│   ├── ChatMessage.swift     # Chat models
│   └── PipelineProgress.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── PinEntryView.swift
│   ├── Garage/
│   │   └── GarageView.swift
│   ├── Wizard/
│   │   └── NewBuildWizardView.swift
│   ├── BuildDetail/
│   │   └── BuildDetailView.swift
│   └── Chat/
│       └── MechanicChatView.swift
├── ViewModels/
│   ├── GarageViewModel.swift
│   ├── WizardViewModel.swift
│   ├── BuildDetailViewModel.swift
│   └── ChatViewModel.swift
├── Services/
│   ├── APIClient.swift       # REST API client
│   ├── SSEClient.swift       # Server-Sent Events for build progress
│   ├── KeychainService.swift # Secure token storage
│   └── AuthService.swift     # Authentication state
└── Utilities/
    ├── Theme.swift           # Colors, fonts, styles
    └── Extensions.swift      # Helper extensions
```

## Features

### Authentication
- Magic link email login
- 4-digit PIN for quick re-login
- Session tokens stored securely in Keychain

### Garage
- View up to 3 saved builds
- Build cards with summary stats
- Pull to refresh

### New Build Wizard
- Multi-step form for vehicle and intent input
- Real-time SSE progress during build generation
- Step-by-step visual progress

### Build Details
- Performance estimates (before/after)
- Staged modifications with synergy groups
- DIY vs Shop indicators
- Difficulty and time estimates
- Parts search links
- Shop finder links

### Mechanic Chat
- AI chat with build context
- Message history
- Typing indicators

## Architecture

- **MVVM** pattern with SwiftUI
- **Async/await** for networking
- **@Published** properties for reactive UI
- **Keychain** for secure storage
- **SSE** for real-time progress updates

## API Configuration

The API base URL is configured in `APIClient.swift`:

```swift
#if DEBUG
private let baseURL = "http://localhost:3000"
#else
private let baseURL = "https://api.tunedup.dev"
#endif
```

For local development, ensure the backend is running on `localhost:3000`.

## Deep Links

The app handles magic link authentication via URL scheme:

```
tunedup://auth/verify?token=xxx
```

Configure this in your Xcode project's URL Types.

## Theme

The app uses a dark theme defined in `Utilities/Theme.swift`:
- Background: `#0A0A0A`
- Surface: `#1A1A1A`
- Primary: `#3B82F6` (blue)

## License

Proprietary - All rights reserved
