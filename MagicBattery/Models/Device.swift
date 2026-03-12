import Foundation
import SwiftUI

enum DeviceSource: String, Codable {
    case mac
    case bluetooth
    case libimobiledeviceUSB
    case libimobiledeviceNetwork
    case companionProxy

    var displayName: String? {
        switch self {
        case .mac:
            return nil
        case .bluetooth:
            return String(localized: "device.source.bluetooth")
        case .libimobiledeviceUSB:
            return String(localized: "device.source.usb")
        case .libimobiledeviceNetwork:
            return String(localized: "device.source.network")
        case .companionProxy:
            return String(localized: "device.source.via_iphone")
        }
    }
}

/// 设备模型
struct Device: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: DeviceType
    private(set) var batteryLevel: Int
    let isCharging: Bool
    let lastUpdated: Date
    let externalIdentifier: String?
    let parentExternalIdentifier: String?
    let source: DeviceSource
    let detailText: String?
    let isStale: Bool

    /// 初始化设备
    /// - Parameters:
    ///   - id: 设备唯一标识符
    ///   - name: 设备名称
    ///   - type: 设备类型
    ///   - batteryLevel: 电池电量（-1 表示未知，0-100 表示实际电量）
    ///   - isCharging: 是否正在充电
    ///   - lastUpdated: 最后更新时间
    init(
        id: UUID,
        name: String,
        type: DeviceType,
        batteryLevel: Int,
        isCharging: Bool,
        lastUpdated: Date,
        externalIdentifier: String? = nil,
        parentExternalIdentifier: String? = nil,
        source: DeviceSource? = nil,
        detailText: String? = nil,
        isStale: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        // 将电池电量限制在 -1 到 100 范围内（-1 表示未知）
        self.batteryLevel = max(-1, min(100, batteryLevel))
        self.isCharging = isCharging
        self.lastUpdated = lastUpdated
        self.externalIdentifier = externalIdentifier
        self.parentExternalIdentifier = parentExternalIdentifier
        self.source = source ?? (type == .mac ? .mac : .bluetooth)
        self.detailText = detailText
        self.isStale = isStale
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case batteryLevel
        case isCharging
        case lastUpdated
        case externalIdentifier
        case parentExternalIdentifier
        case source
        case detailText
        case isStale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let type = try container.decode(DeviceType.self, forKey: .type)
        let batteryLevel = try container.decode(Int.self, forKey: .batteryLevel)
        let isCharging = try container.decode(Bool.self, forKey: .isCharging)
        let lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
        let externalIdentifier = try container.decodeIfPresent(String.self, forKey: .externalIdentifier)
        let parentExternalIdentifier = try container.decodeIfPresent(String.self, forKey: .parentExternalIdentifier)
        let source = try container.decodeIfPresent(DeviceSource.self, forKey: .source)
        let detailText = try container.decodeIfPresent(String.self, forKey: .detailText)
        let isStale = try container.decodeIfPresent(Bool.self, forKey: .isStale) ?? false

        self.init(
            id: id,
            name: name,
            type: type,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            lastUpdated: lastUpdated,
            externalIdentifier: externalIdentifier,
            parentExternalIdentifier: parentExternalIdentifier,
            source: source,
            detailText: detailText,
            isStale: isStale
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(isCharging, forKey: .isCharging)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encodeIfPresent(externalIdentifier, forKey: .externalIdentifier)
        try container.encodeIfPresent(parentExternalIdentifier, forKey: .parentExternalIdentifier)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(detailText, forKey: .detailText)
        try container.encode(isStale, forKey: .isStale)
    }

    /// 设备图标
    var icon: DeviceIcon {
        switch type {
        case .mac:
            return .mac
        case .iPhone:
            return .iPhone
        case .iPad:
            return .iPad
        case .appleWatch:
            return .appleWatch
        case .airPods, .airPodsLeft, .airPodsRight, .airPodsCase:
            return .airPods
        case .bluetoothDevice:
            return .bluetooth
        case .bluetoothKeyboard:
            return .keyboard
        case .bluetoothMouse:
            return .mouse
        case .bluetoothHeadphone:
            return .headphone
        }
    }

    /// 电池电量颜色
    /// 注意：此颜色映射是固定阈值（20/30），与通知阈值（可配置）无强绑定。
    var batteryColor: Color {
        batteryColor(lowThreshold: 20)
    }

    /// 根据自定义阈值返回电池颜色
    /// - Parameter lowThreshold: 低电量阈值
    func batteryColor(lowThreshold: Int) -> Color {
        if batteryLevel < 0 {
            return .secondary
        } else if batteryLevel <= lowThreshold {
            return .red
        } else if batteryLevel <= lowThreshold + 10 {
            return .orange
        } else {
            return .green
        }
    }

    func isLowBattery(threshold: Int) -> Bool {
        batteryLevel >= 0 && batteryLevel < threshold
    }

    /// 是否为低电量（使用默认阈值 20%）
    var isLowBattery: Bool {
        return isLowBattery(threshold: 20)
    }

    /// 电池电量是否未知
    var isBatteryUnknown: Bool {
        return batteryLevel < 0
    }

    var sourceLabel: String? {
        source.displayName
    }

    var statusText: String? {
        if isStale {
            return detailText ?? String(localized: "device.status.offline")
        }
        return detailText
    }

    var supportsTypeOverride: Bool {
        source == .bluetooth && type != .mac
    }
}
