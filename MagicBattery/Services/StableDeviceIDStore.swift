import Foundation

/// 为外部设备生成稳定 UUID，避免列表刷新时 ID 抖动。
final class StableDeviceIDStore {
    static let shared = StableDeviceIDStore()

    private let defaults = UserDefaults.standard

    private init() {}

    func id(namespace: String, key: String) -> UUID {
        let defaultsKey = "StableDeviceID.\(namespace).\(key)"
        if let uuidString = defaults.string(forKey: defaultsKey),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: defaultsKey)
        return uuid
    }
}
