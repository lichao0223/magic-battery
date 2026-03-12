# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build (Debug)
xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS'

# Build (Release)
xcodebuild -scheme battery -configuration Release -destination 'platform=macOS'

# Run all tests
xcodebuild test -scheme battery -destination 'platform=macOS'

# Run a single test class
xcodebuild test -scheme battery -destination 'platform=macOS' -only-testing:batteryTests/DeviceTests

# Run a single test method
xcodebuild test -scheme battery -destination 'platform=macOS' -only-testing:batteryTests/DeviceTests/testBatteryColor
```

**Important**: Do not combine `-arch` and `-destination` flags — they conflict. Use `-destination 'platform=macOS'` alone.

CI runs on GitHub Actions (`macos-26` runner, Xcode 26.3). See `.github/workflows/build.yml`.

## Project Overview

MagicBattery is a macOS menu bar app that monitors battery status of Mac, Bluetooth devices, and trusted iPhone/iPad/Apple Watch. It has three Xcode targets:

| Target | Type | Product |
|---|---|---|
| `battery` | Main app | `MagicBattery.app` |
| `BatteryWidgetExtension` | Widget extension | `BatteryWidgetExtension.appex` |
| `batteryTests` | Unit tests | `batteryTests.xctest` |

The Swift module name is **`MagicBattery`** (set via `PRODUCT_NAME`), not `battery`. Tests must use `@testable import MagicBattery`.

## Architecture

**MVVM + Service Layer** with Combine reactive data flow.

### Data Flow

```
Services (DeviceManager protocol)
    → CompositeDeviceManager (aggregates 3 services)
        → DeviceListViewModel (@Published devices)
            → SwiftUI Views (MenuBarPopoverView, DeviceRowView, etc.)
            → NotificationManager (low battery alerts)
            → WidgetDataManager (syncs to widget via App Group)
```

### App Lifecycle

Entry point: `batteryApp.swift` → `AppDelegate` (via `@NSApplicationDelegateAdaptor`).

`applicationDidFinishLaunching` creates the service composition:
1. Three `DeviceManager` implementations → `CompositeDeviceManager`
2. `DeviceListViewModel` subscribes to combined device publisher
3. `MenuBarManager` renders status bar icon and popover
4. Combine pipelines auto-trigger notifications and widget sync on device changes

### Three Device Services

| Service | Framework | What it monitors |
|---|---|---|
| `MacBatteryService` | IOKit (`IOPSCopyPowerSourcesInfo`) | Mac internal battery |
| `BluetoothDeviceService` | IOBluetooth + CoreBluetooth | Paired BT devices (keyboard, mouse, AirPods, etc.) |
| `IOSDeviceService` | libimobiledevice CLI tools | Trusted iPhone/iPad + Apple Watch via companion proxy |

All implement the `DeviceManager` protocol which exposes `devicesPublisher: AnyPublisher<[Device], Never>`.

`IOSDeviceService` uses `IOSDeviceEventMonitor` (IOKit USB notifications) for event-driven refresh instead of polling, with a 3-minute fallback timer.

### Widget Data Sharing

Main app and widget share data via App Group (`group.com.lc.battery`):
- `WidgetDataManager` encodes `[Device]` to JSON in shared `UserDefaults`
- Uses a lightweight signature (device count + battery levels + charging states) to skip redundant writes
- Calls `WidgetCenter.shared.reloadAllTimelines()` when data changes

### Key Model: Device

`Device` is a Codable struct with battery level clamped to `[-1, 100]` (-1 = unknown). Key computed properties: `isLowBattery`, `isBatteryUnknown`, `batteryColor` (returns SwiftUI `Color`).

`DeviceSource` enum tracks origin: `.mac`, `.bluetooth`, `.libimobiledeviceUSB`, `.libimobiledeviceNetwork`, `.companionProxy`.

## Logging

`AppLogger` (in `Utils/AppLogger.swift`) wraps `os.Logger` with category-based loggers. When calling logging methods, use explicit category references:

```swift
// Correct
AppLogger.debug("message", category: AppLogger.ios)

// Wrong — .ios resolves against os.Logger, not AppLogger
AppLogger.debug("message", category: .ios)
```

Available categories: `app`, `bluetooth`, `ios`, `mac`, `notification`, `widget`, `permission`, `ui`.

## Xcode Project Structure

The project uses **PBXFileSystemSynchronizedRootGroup** for the `MagicBattery/` directory — files are auto-included in the main target. Do not add explicit `PBXBuildFile` entries for files under synchronized groups.

For the widget extension to compile files from `MagicBattery/`, add them to `membershipExceptions` in the extension's `PBXFileSystemSynchronizedBuildFileExceptionSet`.

## Localization

Two languages: English (`en.lproj/Localizable.strings`) and Simplified Chinese (`zh-Hans.lproj/Localizable.strings`).

Uses `String(localized: "key")` for runtime strings. For SwiftUI `Text` views that need localization, parameters must use `LocalizedStringKey` type — not `String` — so `Text(key)` calls the localizing initializer.

## Dependencies

Pre-compiled `libimobiledevice` tools are bundled in `Vendor/libimobiledevice/` (bin + dylibs). `IDeviceToolRunner` resolves tool paths from the app bundle first, then falls back to `/opt/homebrew/bin`, `/usr/local/bin`, `/usr/bin` with a path whitelist for security.
