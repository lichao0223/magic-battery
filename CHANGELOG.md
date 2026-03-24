# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-03-05

### Added

#### Core Features
- Mac battery monitoring with real-time updates
- Bluetooth device battery monitoring (keyboard, mouse, headphones, AirPods)
- Menu bar icon with battery status display
- Low battery notifications with customizable threshold
- Device list with sorting and filtering options
- Widget support (small, medium, large sizes)

#### Models
- `Device` struct with battery level clamping (0-100)
- `DeviceType` enum with 11 device types and Chinese display names
- `DeviceIcon` enum mapping to SF Symbols
- Computed properties: `batteryColor`, `isLowBattery`, `icon`

#### Services
- `DeviceManager` protocol for device management abstraction
- `MacBatteryService` using IOKit for Mac battery monitoring
- `BluetoothDeviceService` using IOBluetooth for BT device monitoring
- `CompositeDeviceManager` for aggregating multiple device managers
- `NotificationManager` for system notifications with deduplication
- `PermissionManager` for unified permission handling
- `ErrorHandler` for centralized error management
- `PerformanceMonitor` for tracking operation execution times
- `MemoryMonitor` for memory usage tracking

#### ViewModels
- `DeviceListViewModel` with MVVM architecture
- Reactive updates using Combine framework
- Sorting options: battery level, name, last updated, device type
- Filtering options: all, low battery, charging, by type

#### Views
- `MenuBarManager` for status bar icon and popover management
- `MenuBarPopoverView` with device list display
- `DeviceRowView` for individual device information
- `SettingsView` with notification, update, and app preferences
- `PermissionRequestView` for onboarding and permission requests
- `BatteryIconView` for visual battery level representation

#### Widgets
- `BatteryWidget` with three size variants
- `BatteryWidgetProvider` for timeline management
- `WidgetDataManager` for App Group data sharing
- Automatic updates every 5 minutes

#### Testing
- Unit tests for Device model
- Battery level validation tests
- Device type and icon mapping tests
- Computed properties tests

#### Documentation
- Comprehensive README.md
- PROJECT_SUMMARY.md with implementation details
- DEVELOPMENT.md with development guidelines
- CHANGELOG.md for version tracking

### Technical Highlights

#### Architecture
- MVVM pattern with clear separation of concerns
- Protocol-oriented design for flexibility
- Service layer for business logic isolation

#### Performance
- Device information caching using NSCache
- Performance monitoring and statistics
- Memory usage tracking
- Operation execution time measurement

#### Error Handling
- Centralized error management system
- Error logging with severity levels
- Automatic error notifications for critical issues
- Comprehensive error types

#### Data Persistence
- UserDefaults for device ID storage
- App Group for widget data sharing
- JSON encoding/decoding for device data

### Known Limitations

- Bluetooth device battery level returns fixed value (100%)
- AirPods individual earbud battery levels not supported
- Limited test coverage (only Model layer)

### Dependencies

- Swift 5.9+
- SwiftUI
- Combine
- WidgetKit
- IOKit
- IOBluetooth
- UserNotifications

### System Requirements

- macOS 15.6 or later
- Xcode 26.0 or later

### Permissions Required

- Notification permission (required)
- Bluetooth permission (required)
- Accessibility permission (optional)

---

## [Unreleased]

### Planned Features

- Real Bluetooth device battery level detection
- AirPods individual earbud support
- Battery history and charts
- Custom notification sounds
- Dark mode optimization
- Multi-language support (English, Chinese)
- Data export functionality
- Cloud sync capabilities

### Planned Improvements

- Complete unit test coverage
- UI tests
- Integration tests
- Widget performance optimization
- Battery trend analysis
- Apple Watch companion app

---

## Version History

- **0.0.1** (2026-03-05) - Initial release

---

## Git Commit History

```
f1aff58 - docs: add comprehensive documentation
a3196f2 - feat: implement widget support
5e04644 - feat: add error handling and performance monitoring
e6fb503 - feat: implement permission management system
92da512 - feat: implement menu bar UI and app integration
ef8dfce - feat: implement NotificationManager
b358796 - feat: implement DeviceListViewModel
b468036 - feat: implement device management services
5308a1c - feat: add Device and DeviceType models with tests
7ea0a16 - Initial Commit
```

---

For more details, see the [README](README.md) and [PROJECT_SUMMARY](PROJECT_SUMMARY.md).
