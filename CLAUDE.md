# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This is an Xcode project — all building, running, and testing is done through Xcode or `xcodebuild`.

```bash
# Build from command line (main app)
xcodebuild -project "Boxing timer.xcodeproj" -scheme "Boxing timer" -destination "platform=iOS Simulator,name=iPhone 16" build

# Run UI tests
xcodebuild -project "Boxing timer.xcodeproj" -scheme "Boxing timer" -destination "platform=iOS Simulator,name=iPhone 16" test

# Build widget extension
xcodebuild -project "Boxing timer.xcodeproj" -scheme "BoxingTimerWidgetExtension" -destination "platform=iOS Simulator,name=iPhone 16" build
```

Minimum deployment target: **iOS 16.0**. Requires Xcode 15+.

## Architecture

**MVVM with SwiftUI and Combine.** No UIKit. ViewModels use `@Published` properties and conform to `ObservableObject`; views observe them via `@StateObject`/`@ObservedObject`.

### Targets

- **Boxing timer** — main app
- **BoxingTimerWidgetExtension** — Live Activity / Dynamic Island widget
- **Boxing timerUITests** — UI test suite

### Key Source Files

| File | Role |
|------|------|
| `Boxing_timerApp.swift` | App entry point; tab-based root navigation |
| `ViewModels.swift` | `FightTimerViewModel`, `IntervalTimerViewModel`, related inner views |
| `Views.swift` | `IntervalTimerView`, `HistoryView`, `StatsView`, `StopwatchView`, `DonationView`, `SettingsView` |
| `ModelsAndStubs.swift` | Data models, enums (`TimerPhase`, `TimerStatus`), `SoundManager`, `ProfileManager` |
| `LanguageManager.swift` | All translations for 6 languages (German, English, Arabic, Spanish, French, Russian) |
| `UserSettings.swift` | `UserDefaults`-backed user preferences (sound, haptics, warnings) |
| `Persistence.swift` | Core Data stack (`PersistenceController`) |
| `TodoManager.swift` | Todo CRUD + `UserNotifications` scheduling |
| `DonationManager.swift` | StoreKit 2 IAP (3 consumable tip products) |
| `AppPromptManager.swift` | Review request and donation prompt timing logic |
| `BoxingTimerAttributes.swift` | `ActivityAttributes` model shared between app and widget |
| `BoxingTimerWidget/BoxingTimerLiveActivity.swift` | Lock screen + Dynamic Island UI |

### Data Persistence

- **UserDefaults** — user settings, todo list, custom timer profiles, language selection, app usage metrics
- **Core Data** — workout history (`WorkoutHistoryEntity`): date, sportName, mode, rounds, durations, totalDuration
- No backend; all data is on-device

### Localization

All user-facing strings go through `LanguageManager` (not `NSLocalizedString`). The manager returns translated strings based on the user's selected language stored in UserDefaults. RTL layout is handled for Arabic. When adding new strings, add translations for all 6 languages in `LanguageManager.swift`.

### Sound & Haptics

`SoundManager` (in `ModelsAndStubs.swift`) handles all audio (AVFoundation) and haptics (CoreHaptics / UIImpactFeedbackGenerator). Audio session is configured for `.playback` category so timer sounds mix with the user's music.

### Live Activity

`FightTimerViewModel` starts/updates/ends a Live Activity using ActivityKit. The shared data type is `BoxingTimerAttributes` (in `BoxingTimerAttributes.swift`). The widget renders compact, expanded, and Dynamic Island presentations in `BoxingTimerLiveActivity.swift`. Live Activity requires iOS 16.2+; guard with availability checks.

### In-App Purchases

`DonationManager` uses StoreKit 2 async/await APIs. The StoreKit configuration file is `StoreKitConfig.storekit` (used for local testing in Xcode). Three consumable products are defined there.
