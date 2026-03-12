import Foundation

/// 设备类型枚举
enum DeviceType: String, Codable, CaseIterable {
    case mac
    case iPhone
    case iPad
    case appleWatch
    case airPods
    case airPodsLeft
    case airPodsRight
    case airPodsCase
    case bluetoothDevice
    case bluetoothKeyboard
    case bluetoothMouse
    case bluetoothHeadphone

    /// 设备类型的本地化显示名称
    var displayName: String {
        switch self {
        case .mac:
            return String(localized: "device.type.mac")
        case .iPhone:
            return String(localized: "device.type.iphone")
        case .iPad:
            return String(localized: "device.type.ipad")
        case .appleWatch:
            return String(localized: "device.type.apple_watch")
        case .airPods:
            return String(localized: "device.type.airpods")
        case .airPodsLeft:
            return String(localized: "device.type.airpods_left")
        case .airPodsRight:
            return String(localized: "device.type.airpods_right")
        case .airPodsCase:
            return String(localized: "device.type.airpods_case")
        case .bluetoothDevice:
            return String(localized: "device.type.bluetooth_device")
        case .bluetoothKeyboard:
            return String(localized: "device.type.bluetooth_keyboard")
        case .bluetoothMouse:
            return String(localized: "device.type.bluetooth_mouse")
        case .bluetoothHeadphone:
            return String(localized: "device.type.bluetooth_headphone")
        }
    }
}
