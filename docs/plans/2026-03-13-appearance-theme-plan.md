# Appearance Theme Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Follow System / Light / Dark appearance mode toggle to MagicBattery settings, adapting all hardcoded colors for dark mode.

**Architecture:** Use `@AppStorage("appearanceMode")` to persist the choice, `.preferredColorScheme()` on the root popover view to control the mode, and `@Environment(\.colorScheme)` in GlassSurface components to switch between light/dark palettes. Text colors change from hardcoded `Color.black.opacity()` to semantic `Color.primary`/`.secondary`.

**Tech Stack:** SwiftUI, @AppStorage, @Environment(\.colorScheme)

---

### Task 1: Add localization keys

**Files:**
- Modify: `MagicBattery/Resources/en.lproj/Localizable.strings`
- Modify: `MagicBattery/Resources/zh-Hans.lproj/Localizable.strings`

**Step 1: Add English localization keys**

In `en.lproj/Localizable.strings`, add after the `"settings.app.launch_description"` line:

```
"settings.app.appearance" = "Appearance";
"settings.app.appearance.system" = "System";
"settings.app.appearance.light" = "Light";
"settings.app.appearance.dark" = "Dark";
```

**Step 2: Add Chinese localization keys**

In `zh-Hans.lproj/Localizable.strings`, add after the `"settings.app.launch_description"` line:

```
"settings.app.appearance" = "外观";
"settings.app.appearance.system" = "跟随系统";
"settings.app.appearance.light" = "浅色";
"settings.app.appearance.dark" = "暗色";
```

**Step 3: Commit**

```bash
git add MagicBattery/Resources/en.lproj/Localizable.strings MagicBattery/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add localization keys for appearance mode setting"
```

---

### Task 2: Adapt GlassSurface.swift for dark mode

This is the core infrastructure task. Every surface, background, and button style needs colorScheme-aware palettes.

**Files:**
- Modify: `MagicBattery/Views/GlassSurface.swift`

**Step 1: Add colorScheme to BatteryAtmosphereBackground**

Replace the current `BatteryAtmosphereBackground` struct with a colorScheme-aware version:

```swift
struct BatteryAtmosphereBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.10, blue: 0.16),
                        Color(red: 0.10, green: 0.14, blue: 0.18),
                        Color(red: 0.08, green: 0.12, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 220, height: 220)
                    .blur(radius: 28)
                    .offset(x: -90, y: -120)

                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .offset(x: 110, y: 120)

                Circle()
                    .fill(Color.mint.opacity(0.06))
                    .frame(width: 140, height: 140)
                    .blur(radius: 24)
                    .offset(x: 100, y: -90)
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.80, green: 0.88, blue: 0.97),
                        Color(red: 0.90, green: 0.95, blue: 0.88),
                        Color(red: 0.83, green: 0.91, blue: 0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 220, height: 220)
                    .blur(radius: 28)
                    .offset(x: -90, y: -120)

                Circle()
                    .fill(Color.cyan.opacity(0.22))
                    .frame(width: 180, height: 180)
                    .blur(radius: 30)
                    .offset(x: 110, y: 120)

                Circle()
                    .fill(Color.mint.opacity(0.18))
                    .frame(width: 140, height: 140)
                    .blur(radius: 24)
                    .offset(x: 100, y: -90)
            }
        }
    }
}
```

**Step 2: Convert batteryCardSurface to colorScheme-aware ViewModifier**

Replace the `batteryCardSurface` extension function with a ViewModifier struct. The extension becomes:

```swift
func batteryCardSurface(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
    modifier(BatteryCardSurfaceModifier(cornerRadius: cornerRadius, tint: tint))
}
```

Add the modifier struct (can be private):

```swift
private struct BatteryCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            content
                .background {
                    shape
                        .fill(cardGradient)
                        .overlay(
                            shape.stroke(borderColor, lineWidth: 1)
                        )
                        .shadow(color: shadowColor, radius: 12, y: 6)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(borderColor, lineWidth: 0.8)
                )
        }
    }

    private var cardGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.97),
                    Color(red: 0.94, green: 0.97, blue: 0.99).opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.88)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.08)
    }
}
```

**Step 3: Convert batterySectionSurface to colorScheme-aware ViewModifier**

Replace the `batterySectionSurface` extension function:

```swift
func batterySectionSurface(cornerRadius: CGFloat = 22) -> some View {
    modifier(BatterySectionSurfaceModifier(cornerRadius: cornerRadius))
}
```

Add the modifier struct:

```swift
private struct BatterySectionSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape
                    .fill(sectionGradient)
                    .overlay(
                        shape.stroke(borderColor, lineWidth: 1)
                    )
                    .shadow(color: shadowColor, radius: 10, y: 5)
            }
    }

    private var sectionGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.76),
                    Color.white.opacity(0.58)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.64)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? .clear : .black.opacity(0.05)
    }
}
```

**Step 4: Make BatteryHairline colorScheme-aware**

```swift
struct BatteryHairline: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(colorScheme == .dark ? 0.16 : 0.72),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .opacity(colorScheme == .dark ? 0.50 : 0.72)
    }
}
```

**Step 5: Make BatteryControlButtonStyle colorScheme-aware**

Add `@Environment(\.colorScheme) private var colorScheme` to `BatteryControlButtonStyle` and update all color-returning properties:

```swift
private struct BatteryControlButtonStyle: ButtonStyle {
    let tone: BatteryControlTone
    let compact: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        // ... (keep existing layout code, metrics, scaleEffect, animation) ...
    }

    private var foregroundColor: Color {
        switch tone {
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(0.82) : Color.black.opacity(0.78)
        case .prominent:
            return .white
        case .destructive:
            return colorScheme == .dark
                ? Color(red: 0.96, green: 0.42, blue: 0.40)
                : Color(red: 0.58, green: 0.15, blue: 0.14)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .secondary:
            return colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.72)
        case .prominent:
            return Color.white.opacity(0.24)
        case .destructive:
            return colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.70)
        }
    }

    private var shadowColor: Color {
        if colorScheme == .dark { return .clear }
        switch tone {
        case .secondary:
            return .black.opacity(0.08)
        case .prominent:
            return Color(red: 0.05, green: 0.25, blue: 0.32).opacity(0.24)
        case .destructive:
            return Color.red.opacity(0.10)
        }
    }

    private func background(_ isPressed: Bool) -> LinearGradient {
        switch tone {
        case .secondary:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(isPressed ? 0.10 : 0.14),
                        Color.white.opacity(isPressed ? 0.06 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(isPressed ? 0.70 : 0.82),
                        Color.white.opacity(isPressed ? 0.56 : 0.68)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .prominent:
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.72, blue: 0.92).opacity(isPressed ? 0.84 : 0.96),
                    Color(red: 0.09, green: 0.46, blue: 0.74).opacity(isPressed ? 0.88 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .destructive:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color.red.opacity(isPressed ? 0.20 : 0.14),
                        Color.red.opacity(isPressed ? 0.14 : 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color.white.opacity(isPressed ? 0.72 : 0.82),
                        Color(red: 1, green: 0.95, blue: 0.95).opacity(isPressed ? 0.62 : 0.76)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}
```

**Step 6: Make BatteryToolbarChipModifier colorScheme-aware**

Add `@Environment(\.colorScheme) private var colorScheme` and update the border:

```swift
private struct BatteryToolbarChipModifier: ViewModifier {
    let tint: Color
    let foreground: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                tint.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.68),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: colorScheme == .dark ? .clear : .black.opacity(0.05), radius: 8, y: 4)
            }
    }
}
```

**Step 7: Build to verify compilation**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 8: Commit**

```bash
git add MagicBattery/Views/GlassSurface.swift
git commit -m "feat: adapt GlassSurface design system for dark mode support"
```

---

### Task 3: Adapt MenuBarPopoverView.swift

Replace all hardcoded `Color.black.opacity()` text colors with semantic colors and add `.preferredColorScheme()` at the root.

**Files:**
- Modify: `MagicBattery/Views/MenuBarPopoverView.swift`

**Step 1: Add @AppStorage and preferredColorScheme**

Add to the struct properties:

```swift
@AppStorage("appearanceMode") private var appearanceMode = 0
```

Add a computed property:

```swift
private var resolvedColorScheme: ColorScheme? {
    switch appearanceMode {
    case 1: return .light
    case 2: return .dark
    default: return nil
    }
}
```

Add `.preferredColorScheme(resolvedColorScheme)` to the end of the `body` view, after `.batteryPanelSurface(...)`:

```swift
var body: some View {
    Group { ... }
    .frame(width: 382, height: 622, alignment: .top)
    .padding(10)
    .background(BatteryAtmosphereBackground())
    .batteryPanelSurface(cornerRadius: 30, tint: Color.white.opacity(0.08))
    .preferredColorScheme(resolvedColorScheme)
    .sheet(item: $selectedDevice) { device in
        DeviceDetailsSheet(device: device)
    }
}
```

**Step 2: Replace hardcoded text colors**

Replace throughout the file:

| Location | Old | New |
|---|---|---|
| headerView title (line 56) | `Color.black.opacity(0.82)` | `Color.primary` |
| headerView subtitle (line 60) | `Color.black.opacity(0.56)` | `Color.secondary` |
| loadingView text (line 146) | `Color.black.opacity(0.56)` | `Color.secondary` |
| emptyView title (line 159) | `Color.black.opacity(0.76)` | `Color.primary` |
| emptyView subtitle (line 162) | `Color.black.opacity(0.54)` | `Color.secondary` |
| sectionHeader title (line 274) | `Color.black.opacity(0.62)` | `Color.secondary` |
| sectionHeader chip foreground (line 280) | `Color.black.opacity(0.60)` | `Color.secondary` |

**Step 3: Build to verify**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add MagicBattery/Views/MenuBarPopoverView.swift
git commit -m "feat: adapt MenuBarPopoverView for dark mode with preferredColorScheme"
```

---

### Task 4: Adapt DeviceRowView.swift

Replace hardcoded text and background colors with semantic equivalents.

**Files:**
- Modify: `MagicBattery/Views/DeviceRowView.swift`

**Step 1: Replace hardcoded text colors**

Replace throughout the file:

| Location | Old | New |
|---|---|---|
| Icon foreground (line 61) | `Color.black.opacity(0.70)` | `Color.primary.opacity(0.85)` |
| Device name (line 68) | `Color.black.opacity(0.82)` | `Color.primary` |
| Device type (line 75) | `Color.black.opacity(0.56)` | `Color.secondary` |
| Source label chip tint (line 84) | `Color.black.opacity(0.06)` | `Color.primary.opacity(0.06)` |
| Source label chip foreground (line 85) | `Color.black.opacity(0.64)` | `Color.secondary` |
| Status text (line 104) | `Color.black.opacity(0.52)` | `Color.secondary` |
| Unknown battery text (line 121) | `Color.black.opacity(0.58)` | `Color.secondary` |
| Unknown icon (line 133) | `Color.black.opacity(0.48)` | `Color.secondary` |
| Chevron (line 201) | `Color.black.opacity(0.36)` | `Color.secondary.opacity(0.6)` |

**Step 2: Make icon background colorScheme-aware**

Add `@Environment(\.colorScheme) private var colorScheme` to the struct.

Replace the icon background gradient (lines 44-53):

```swift
RoundedRectangle(cornerRadius: 14, style: .continuous)
    .fill(
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.10), Color.white.opacity(0.06)]
                : [Color.white.opacity(0.92), Color(red: 0.92, green: 0.96, blue: 0.99).opacity(0.86)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.88), lineWidth: 1)
    )
```

**Step 3: Make battery badge border colorScheme-aware**

Replace `Color.white.opacity(0.72)` in battery badge capsule stroke (line 143) with:

```swift
colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.72)
```

**Step 4: Update batteryBadgeFill for dark mode**

The `batteryBadgeFill` computed property uses `Color.black.opacity()` for the unknown case. Replace:

```swift
if device.isBatteryUnknown {
    base = [
        Color.primary.opacity(0.05),
        Color.primary.opacity(0.03)
    ]
}
```

(The `.red`, `.orange`, `.mint`, `.cyan` tinted variants work fine in both modes since they're already semi-transparent.)

**Step 5: Build to verify**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add MagicBattery/Views/DeviceRowView.swift
git commit -m "feat: adapt DeviceRowView for dark mode"
```

---

### Task 5: Adapt DeviceDetailsSheet.swift

Replace hardcoded text and background colors.

**Files:**
- Modify: `MagicBattery/Views/DeviceDetailsSheet.swift`

**Step 1: Add colorScheme to DeviceDetailsSheet**

Add to `DeviceDetailsSheet`:

```swift
@Environment(\.colorScheme) private var colorScheme
```

**Step 2: Replace hardcoded text colors in DeviceDetailsSheet**

| Location | Old | New |
|---|---|---|
| Icon foreground (line 72) | `Color.black.opacity(0.74)` | `Color.primary.opacity(0.85)` |
| Device name (line 79) | `Color.black.opacity(0.82)` | `Color.primary` |
| Subtitle (line 84) | `Color.black.opacity(0.56)` | `Color.secondary` |
| Loading text (line 123) | `Color.black.opacity(0.58)` | `Color.secondary` |
| Error title (line 152) | `Color.black.opacity(0.78)` | `Color.primary` |
| Error hint (line 155) | `Color.black.opacity(0.54)` | `Color.secondary` |
| Footnote tone (line 139) | `Color.black.opacity(0.62)` | `Color.secondary` |

**Step 3: Make icon background colorScheme-aware**

Replace the header icon background gradient (lines 56-64):

```swift
RoundedRectangle(cornerRadius: 18, style: .continuous)
    .fill(
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.10), Color.white.opacity(0.06)]
                : [Color.white.opacity(0.94), Color(red: 0.92, green: 0.97, blue: 0.99).opacity(0.88)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .overlay(
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.88), lineWidth: 1)
    )
```

**Step 4: Make battery badge colorScheme-aware**

Replace `Color.white.opacity(0.78)` and `Color.white.opacity(0.72)` in `batteryBadge` (lines 199-203):

```swift
Capsule(style: .continuous)
    .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.78))
    .overlay(
        Capsule(style: .continuous)
            .stroke(colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.72), lineWidth: 1)
    )
```

**Step 5: Replace hardcoded text colors in DeviceDetailSectionCard and DeviceDetailItemRow**

Add `@Environment(\.colorScheme) private var colorScheme` to `DeviceDetailSectionCard`. Replace:

| Location | Old | New |
|---|---|---|
| Section title (line 230) | `Color.black.opacity(0.72)` | `Color.secondary` |

Add `@Environment(\.colorScheme) private var colorScheme` to `DeviceDetailItemRow`. Replace:

| Location | Old | New |
|---|---|---|
| Item title (line 257) | `Color.black.opacity(0.56)` | `Color.secondary` |
| Item value (line 263) | `Color.black.opacity(0.80)` | `Color.primary` |
| Item detail (line 270) | `Color.black.opacity(0.46)` | `Color.secondary.opacity(0.7)` |

Note: After replacing with semantic colors, the `@Environment(\.colorScheme)` is not actually needed in `DeviceDetailSectionCard` and `DeviceDetailItemRow` since `Color.primary`/`.secondary` are inherently colorScheme-aware. Only add it if needed for non-semantic adjustments.

**Step 6: Build to verify**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add MagicBattery/Views/DeviceDetailsSheet.swift
git commit -m "feat: adapt DeviceDetailsSheet for dark mode"
```

---

### Task 6: Add appearance Picker to SettingsView

**Files:**
- Modify: `MagicBattery/Views/SettingsView.swift`

**Step 1: Add @AppStorage for appearance mode**

Add to the existing @AppStorage block at the top of `SettingsView`:

```swift
@AppStorage("appearanceMode") private var appearanceMode = 0
```

**Step 2: Replace hardcoded text colors in SettingsView**

Replace throughout the file:

| Location | Old | New |
|---|---|---|
| Header title (line 81) | `Color.black.opacity(0.82)` | `Color.primary` |
| Header subtitle (line 85) | `Color.black.opacity(0.56)` | `Color.secondary` |
| Threshold label (line 117) | `Color.black.opacity(0.70)` | `Color.primary.opacity(0.85)` |
| Threshold chip foreground (line 125) | `Color.black.opacity(0.72)` | `Color.primary.opacity(0.85)` |
| Update interval label (line 161) | `Color.black.opacity(0.70)` | `Color.primary.opacity(0.85)` |
| Update chip foreground (line 170) | `Color.black.opacity(0.72)` | `Color.primary.opacity(0.85)` |
| BLE interval label (line 196) | `Color.black.opacity(0.70)` | `Color.primary.opacity(0.85)` |
| BLE chip foreground (line 205) | `Color.black.opacity(0.72)` | `Color.primary.opacity(0.85)` |
| sectionCard title (line 365) | `Color.black.opacity(0.80)` | `Color.primary` |
| sectionCard subtitle (line 370) | `Color.black.opacity(0.54)` | `Color.secondary` |

**Step 3: Add appearance Picker to appSection**

In the `appSection` computed property, add the Picker after the launch-at-login toggle and before the description text. Insert between the `.toggleStyle(.switch)` of launch_at_login and `Text("settings.app.launch_description")`:

```swift
Picker(selection: $appearanceMode) {
    Text("settings.app.appearance.system").tag(0)
    Text("settings.app.appearance.light").tag(1)
    Text("settings.app.appearance.dark").tag(2)
} label: {
    Text("settings.app.appearance")
        .font(.system(size: 12, weight: .medium))
}
.pickerStyle(.segmented)
```

**Step 4: Add preferredColorScheme to body**

Add `.preferredColorScheme()` to the SettingsView body. Add a computed property:

```swift
private var resolvedColorScheme: ColorScheme? {
    switch appearanceMode {
    case 1: return .light
    case 2: return .dark
    default: return nil
    }
}
```

Apply it on the `.frame()` in body, before `.padding()`:

```swift
var body: some View {
    Group { ... }
    .frame(width: 512, height: 560)
    .preferredColorScheme(resolvedColorScheme)
    .padding(14)
    .background(BatteryAtmosphereBackground())
    .batteryPanelSurface(cornerRadius: 32, tint: Color.white.opacity(0.08))
}
```

**Step 5: Update resetToDefaults()**

Add `appearanceMode = 0` to the `resetToDefaults()` method.

**Step 6: Build to verify**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add MagicBattery/Views/SettingsView.swift
git commit -m "feat: add appearance mode picker to settings and adapt for dark mode"
```

---

### Task 7: Build, test, and final verification

**Files:** None (verification only)

**Step 1: Run full build**

Run: `xcodebuild -scheme battery -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 2: Run existing tests**

Run: `xcodebuild test -scheme battery -destination 'platform=macOS' 2>&1 | tail -20`
Expected: All tests pass (existing tests should not be affected by color changes)

**Step 3: Commit any remaining fixes if needed**

If build or test failures occur, fix them and commit.
