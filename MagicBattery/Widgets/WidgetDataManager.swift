import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 小组件数据管理器
/// 负责在主应用和小组件之间共享数据
final class WidgetDataManager {
    // MARK: - Singleton

    static let shared = WidgetDataManager()

    // MARK: - Properties

    private let legacyAppGroupIdentifier = "group.com.lc.battery"
    private let devicesKey = "devices"
    private let lastUpdateKey = "lastUpdate"
    private let signatureKey = "devicesSignature"

    private var appGroupIdentifier: String {
        if let configuredValue = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
            let trimmedValue = configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedValue.isEmpty {
                return trimmedValue
            }
        }

        return legacyAppGroupIdentifier
    }

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 保存设备数据到共享容器
    func saveDevices(_ devices: [Device]) {
        guard let sharedDefaults = sharedDefaults else {
            AppLogger.warning("无法访问共享 UserDefaults", category: AppLogger.widget)
            return
        }

        // 快速签名比较：避免全量 JSON encode + data 比较
        let signature = devicesSignature(devices)
        if sharedDefaults.string(forKey: signatureKey) == signature {
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(devices)

            sharedDefaults.set(data, forKey: devicesKey)
            sharedDefaults.set(Date(), forKey: lastUpdateKey)
            sharedDefaults.set(signature, forKey: signatureKey)

            // 通知小组件刷新
            reloadWidgets()
        } catch {
            AppLogger.error("保存设备数据失败: \(error.localizedDescription)", category: AppLogger.widget)
        }
    }

    /// 从共享容器加载设备数据
    func loadDevices() -> [Device]? {
        guard let sharedDefaults = sharedDefaults,
              let data = sharedDefaults.data(forKey: devicesKey) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let devices = try decoder.decode([Device].self, from: data)
            return devices
        } catch {
            AppLogger.error("加载设备数据失败: \(error.localizedDescription)", category: AppLogger.widget)
            return nil
        }
    }

    /// 获取最后更新时间
    func getLastUpdateTime() -> Date? {
        return sharedDefaults?.object(forKey: lastUpdateKey) as? Date
    }

    /// 清除共享数据
    func clearSharedData() {
        guard let sharedDefaults else { return }
        let hadDevices = sharedDefaults.data(forKey: devicesKey) != nil
        let hadUpdateTime = sharedDefaults.object(forKey: lastUpdateKey) != nil
        guard hadDevices || hadUpdateTime else { return }

        sharedDefaults.removeObject(forKey: devicesKey)
        sharedDefaults.removeObject(forKey: lastUpdateKey)
        sharedDefaults.removeObject(forKey: signatureKey)
        reloadWidgets()
    }

    /// 通知小组件刷新
    func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    // MARK: - Private Methods

    /// 生成设备列表的轻量签名（count + battery levels + charging states）
    /// 用于快速判断数据是否变化，避免全量 JSON encode
    private func devicesSignature(_ devices: [Device]) -> String {
        var parts = ["\(devices.count)"]
        for device in devices {
            parts.append("\(device.id.uuidString.prefix(8)):\(device.batteryLevel):\(device.isCharging)")
        }
        return parts.joined(separator: "|")
    }
}
