# Appearance Theme Settings Design

## Goal

Add appearance mode setting (Follow System / Light / Dark) to MagicBattery's settings, using SwiftUI's `.preferredColorScheme()` with semantic colors for automatic dark mode adaptation.

## Data Layer

New `@AppStorage("appearanceMode")` storing an `Int`:
- `0` = Follow System (default)
- `1` = Light
- `2` = Dark

## Appearance Control

Apply `.preferredColorScheme()` on the popover root view and settings sheet:
- `0` → `nil` (follow system)
- `1` → `.light`
- `2` → `.dark`

## Color Adaptation (GlassSurface.swift)

Replace hardcoded colors with colorScheme-aware values:

| Current | Replacement |
|---|---|
| `Color.black.opacity(0.82)` (primary text) | `Color.primary` |
| `Color.black.opacity(0.56)` (secondary text) | `Color.secondary` |
| `Color.white.opacity(0.97)` (card bg) | Dark: deep semi-transparent |
| `BatteryAtmosphereBackground` gradients | Switch gradient palette by colorScheme |
| Button `Color.black/white` references | Dynamic by colorScheme |

## Settings UI

Add a `Picker` (segmented style) in `appSection`:

```
Appearance:  [ System | Light | Dark ]
```

Placed after the existing toggles in the App section.

## Localization

New keys:
- `settings.app.appearance` → "外观" / "Appearance"
- `settings.app.appearance.system` → "跟随系统" / "System"
- `settings.app.appearance.light` → "浅色" / "Light"
- `settings.app.appearance.dark` → "暗色" / "Dark"

## Reset

`resetToDefaults()` sets `appearanceMode` back to `0`.

## Files Affected

- `GlassSurface.swift` — color adaptation (main changes)
- `SettingsView.swift` — add Picker + apply preferredColorScheme
- `MenuBarPopoverView.swift` — apply preferredColorScheme
- `DeviceRowView.swift` — replace hardcoded colors with semantic colors
- `DeviceDetailsSheet.swift` — same
- `en.lproj/Localizable.strings` — add 4 keys
- `zh-Hans.lproj/Localizable.strings` — add 4 keys
