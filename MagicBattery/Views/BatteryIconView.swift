import SwiftUI

/// 电池图标视图
struct BatteryIconView: View {
    let level: Int
    let isCharging: Bool

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(batteryColor)
    }

    private var batteryColor: Color {
        if level <= 20 {
            return .red
        } else if level <= 30 {
            return .orange
        } else {
            return .green
        }
    }

    private var symbolName: String {
        if isCharging {
            return "battery.100.bolt"
        }
        if level <= 10 {
            return "battery.0"
        }
        if level <= 30 {
            return "battery.25"
        }
        if level <= 60 {
            return "battery.50"
        }
        if level <= 85 {
            return "battery.75"
        }
        return "battery.100"
    }
}
