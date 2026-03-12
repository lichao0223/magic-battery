import SwiftUI

/// 设备行视图
/// 显示单个设备的信息
struct DeviceRowView: View {
    let device: Device
    var onTap: (() -> Void)? = nil

    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 20

    var body: some View {
        rowBody
            .contextMenu {
                if device.supportsTypeOverride {
                    Button(String(localized: "device.context.set_keyboard")) {
                        DeviceTypeOverrideStore.shared.setOverrideType(for: device.name, type: .bluetoothKeyboard)
                    }
                    Button(String(localized: "device.context.set_mouse")) {
                        DeviceTypeOverrideStore.shared.setOverrideType(for: device.name, type: .bluetoothMouse)
                    }
                    Button(String(localized: "device.context.clear_override")) {
                        DeviceTypeOverrideStore.shared.setOverrideType(for: device.name, type: nil)
                    }
                }
            }
    }

    @ViewBuilder
    private var rowBody: some View {
        if let onTap {
            Button(action: onTap) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(red: 0.92, green: 0.96, blue: 0.99).opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.88), lineWidth: 1)
                    )

                Image(systemName: device.icon.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color.black.opacity(0.70))
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.82))
                    .lineLimit(1)
                    .layoutPriority(1)

                HStack(spacing: 6) {
                    Text(device.type.displayName)
                        .font(.system(size: 10.5))
                        .foregroundColor(Color.black.opacity(0.56))
                        .lineLimit(1)

                    if let sourceLabel = device.sourceLabel {
                        Text(sourceLabel)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .batteryToolbarChip(
                                tint: Color.black.opacity(0.06),
                                foreground: Color.black.opacity(0.64)
                            )
                    }

                    if device.isStale {
                        Text("device.status.offline")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .batteryToolbarChip(
                                tint: Color.orange.opacity(0.16),
                                foreground: Color(red: 0.74, green: 0.36, blue: 0.04)
                            )
                    }
                }

                if let statusText = device.statusText {
                    Text(statusText)
                        .font(.system(size: 9.5))
                        .foregroundColor(device.isStale ? .orange : Color.black.opacity(0.52))
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 7) {
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.86, green: 0.60, blue: 0.08))
                }

                if device.isBatteryUnknown {
                    Text("common.unknown")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color.black.opacity(0.58))
                } else {
                    Text("\(device.batteryLevel)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(batteryAccentColor)
                }

                if !device.isBatteryUnknown {
                    BatteryIconView(level: device.batteryLevel, isCharging: device.isCharging)
                } else {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.black.opacity(0.48))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(batteryBadgeFill)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
            )

            trailingIndicator
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .batteryCardSurface(cornerRadius: 15, tint: Color.white.opacity(0.05))
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }

    private var batteryAccentColor: Color {
        if device.isBatteryUnknown {
            return Color.black.opacity(0.56)
        }
        if device.batteryLevel <= lowBatteryThreshold {
            return Color(red: 0.79, green: 0.20, blue: 0.18)
        }
        if device.batteryLevel <= lowBatteryThreshold + 10 {
            return Color(red: 0.84, green: 0.46, blue: 0.11)
        }
        return Color(red: 0.12, green: 0.56, blue: 0.38)
    }

    private var batteryBadgeFill: LinearGradient {
        let base: [Color]
        if device.isBatteryUnknown {
            base = [
                Color.black.opacity(0.05),
                Color.black.opacity(0.03)
            ]
        } else if device.batteryLevel <= lowBatteryThreshold {
            base = [
                Color.red.opacity(0.14),
                Color.orange.opacity(0.10)
            ]
        } else if device.batteryLevel <= lowBatteryThreshold + 10 {
            base = [
                Color.orange.opacity(0.16),
                Color.yellow.opacity(0.10)
            ]
        } else {
            base = [
                Color.mint.opacity(0.18),
                Color.cyan.opacity(0.12)
            ]
        }

        return LinearGradient(colors: base, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    @ViewBuilder
    private var trailingIndicator: some View {
        Group {
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color.black.opacity(0.36))
            } else {
                Color.clear
            }
        }
        .frame(width: 11, height: 11)
    }
}

#Preview {
    VStack(spacing: 8) {
        DeviceRowView(device: Device(
            id: UUID(),
            name: "MacBook Pro",
            type: .mac,
            batteryLevel: 85,
            isCharging: true,
            lastUpdated: Date()
        ))

        DeviceRowView(device: Device(
            id: UUID(),
            name: "Magic Mouse",
            type: .bluetoothMouse,
            batteryLevel: 45,
            isCharging: false,
            lastUpdated: Date()
        ))

        DeviceRowView(device: Device(
            id: UUID(),
            name: "AirPods Pro",
            type: .airPods,
            batteryLevel: 15,
            isCharging: false,
            lastUpdated: Date()
        ))

        DeviceRowView(device: Device(
            id: UUID(),
            name: "iPhone 16 Pro",
            type: .iPhone,
            batteryLevel: 68,
            isCharging: false,
            lastUpdated: Date(),
            externalIdentifier: "preview-phone",
            source: .libimobiledeviceNetwork
        ))

        DeviceRowView(device: Device(
            id: UUID(),
            name: "Apple Watch",
            type: .appleWatch,
            batteryLevel: 42,
            isCharging: true,
            lastUpdated: Date(),
            externalIdentifier: "preview-watch",
            parentExternalIdentifier: "preview-phone",
            source: .companionProxy,
            detailText: "iPhone 16 Pro"
        ))
    }
    .padding()
    .frame(width: 300)
}
