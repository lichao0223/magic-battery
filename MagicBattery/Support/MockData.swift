import Foundation

/// 用于 README 截图和本地演示的 Mock 数据
@MainActor
enum MockData {
    static let now = Date()

    static let devices: [Device] = [
        Device(
            id: UUID(uuidString: "A1111111-1111-1111-1111-111111111111")!,
            name: "MacBook Pro",
            type: .mac,
            batteryLevel: 83,
            isCharging: true,
            lastUpdated: now,
            source: .mac,
            detailText: "正在充电 · 83%"
        ),
        Device(
            id: UUID(uuidString: "B2222222-2222-2222-2222-222222222222")!,
            name: "老板的手机",
            type: .iPhone,
            batteryLevel: 61,
            isCharging: false,
            lastUpdated: now.addingTimeInterval(-45),
            externalIdentifier: "00008140-0012345678901234",
            source: .libimobiledeviceNetwork,
            detailText: "同一无线网络在线"
        ),
        Device(
            id: UUID(uuidString: "C3333333-3333-3333-3333-333333333333")!,
            name: "iPad Pro",
            type: .iPad,
            batteryLevel: 47,
            isCharging: true,
            lastUpdated: now.addingTimeInterval(-75),
            externalIdentifier: "00008101-00ABCDEF01234567",
            source: .libimobiledeviceUSB,
            detailText: "USB 已连接"
        ),
        Device(
            id: UUID(uuidString: "D4444444-4444-4444-4444-444444444444")!,
            name: "Apple Watch",
            type: .appleWatch,
            batteryLevel: 36,
            isCharging: false,
            lastUpdated: now.addingTimeInterval(-120),
            externalIdentifier: "WATCH-001",
            parentExternalIdentifier: "00008140-0012345678901234",
            source: .companionProxy,
            detailText: "通过 iPhone 同步"
        ),
        Device(
            id: UUID(uuidString: "E5555555-5555-5555-5555-555555555555")!,
            name: "Magic Keyboard",
            type: .bluetoothKeyboard,
            batteryLevel: 72,
            isCharging: false,
            lastUpdated: now.addingTimeInterval(-30),
            externalIdentifier: "BT-KEYBOARD-001",
            source: .bluetooth,
            detailText: "已连接"
        ),
        Device(
            id: UUID(uuidString: "F6666666-6666-6666-6666-666666666666")!,
            name: "Magic Mouse",
            type: .bluetoothMouse,
            batteryLevel: 28,
            isCharging: false,
            lastUpdated: now.addingTimeInterval(-20),
            externalIdentifier: "BT-MOUSE-001",
            source: .bluetooth,
            detailText: "低电量"
        ),
        Device(
            id: UUID(uuidString: "A7777777-7777-7777-7777-777777777777")!,
            name: "AirPods Pro",
            type: .airPods,
            batteryLevel: 19,
            isCharging: false,
            lastUpdated: now.addingTimeInterval(-15),
            externalIdentifier: "BT-AIRPODS-001",
            source: .bluetooth,
            detailText: "耳机盒未连接"
        )
    ]

    static var detailDevice: Device {
        devices.first(where: { $0.type == .iPhone }) ?? devices[1]
    }

    static var widgetDevices: [Device] {
        [devices[0], devices[4], devices[6], devices[5]]
    }

    static var detailSnapshot: DeviceDetailSnapshot {
        DeviceDetailSnapshot(
            subtitle: "老板的手机 · 无线同步",
            sections: [
                DeviceDetailSection(
                    id: "current",
                    title: "当前状态",
                    items: [
                        DeviceDetailItem(id: "level", title: "电量", value: "61%"),
                        DeviceDetailItem(id: "charging", title: "充电中", value: "否"),
                        DeviceDetailItem(id: "external", title: "外接电源", value: "否"),
                        DeviceDetailItem(id: "full", title: "已充满", value: "否"),
                        DeviceDetailItem(id: "last", title: "最后更新", value: "刚刚")
                    ]
                ),
                DeviceDetailSection(
                    id: "capacity",
                    title: "电池健康",
                    items: [
                        DeviceDetailItem(id: "cycle", title: "循环次数", value: "186"),
                        DeviceDetailItem(id: "health", title: "健康估算", value: "92%", detail: "基于设计容量与当前容量的模拟估算值"),
                        DeviceDetailItem(id: "design", title: "设计容量", value: "3274 mAh"),
                        DeviceDetailItem(id: "nominal", title: "当前容量", value: "3010 mAh")
                    ]
                ),
                DeviceDetailSection(
                    id: "telemetry",
                    title: "遥测信息",
                    items: [
                        DeviceDetailItem(id: "voltage", title: "电压", value: "3890 mV"),
                        DeviceDetailItem(id: "amperage", title: "电流", value: "-420 mA"),
                        DeviceDetailItem(id: "temperature", title: "温度", value: "31.4 °C"),
                        DeviceDetailItem(id: "power", title: "电池功率", value: "1.6 W")
                    ]
                ),
                DeviceDetailSection(
                    id: "meta",
                    title: "设备信息",
                    items: [
                        DeviceDetailItem(id: "name", title: "设备名称", value: "老板的手机"),
                        DeviceDetailItem(id: "product", title: "机型", value: "iPhone17,1"),
                        DeviceDetailItem(id: "system", title: "系统版本", value: "iOS 18.4"),
                        DeviceDetailItem(id: "connection", title: "连接方式", value: "同一无线网络"),
                        DeviceDetailItem(id: "identifier", title: "标识符", value: "00008140-0012345678901234")
                    ]
                )
            ],
            footnote: "这是 README 截图使用的模拟数据，用于稳定展示界面效果。"
        )
    }

    static var detailHistorySamples: [BatteryHistorySample] {
        let calendar = Calendar.current
        let now = Date()
        let points: [(hoursAgo: Int, level: Int, charging: Bool)] = [
            (22, 84, false),
            (18, 78, false),
            (14, 73, false),
            (10, 69, false),
            (7, 65, false),
            (4, 62, false),
            (2, 61, false),
            (0, 61, false)
        ]

        return points.map { point in
            BatteryHistorySample(
                timestamp: calendar.date(byAdding: .hour, value: -point.hoursAgo, to: now) ?? now,
                batteryLevel: point.level,
                isCharging: point.charging
            )
        }
    }

    static func applyScreenshotDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "enableNotifications")
        defaults.set(20, forKey: "lowBatteryThreshold")
        defaults.set(NotificationSoundOption.glass.rawValue, forKey: "notificationSound")
        defaults.set(60, forKey: "updateInterval")
        defaults.set(120, forKey: "bleScanInterval")
        defaults.set(false, forKey: "showInDock")
        defaults.set(true, forKey: "enableIDeviceDiscovery")
        defaults.set(true, forKey: "enableWatchBatteryDiscovery")
        defaults.set(true, forKey: "showOfflineIDevices")
        defaults.set(2, forKey: "appearanceMode")
    }
}
