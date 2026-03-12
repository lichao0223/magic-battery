import Foundation

final class DeviceTypeOverrideStore {
    static let shared = DeviceTypeOverrideStore()
    static let didChangeNotification = Notification.Name("DeviceTypeOverrideStore.didChange")

    private let defaultsKey = "BluetoothDeviceTypeOverridesByName"

    private init() {}

    func allOverrides() -> [String: DeviceType] {
        let raw = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        var result: [String: DeviceType] = [:]
        for (name, typeRawValue) in raw {
            if let type = DeviceType(rawValue: typeRawValue) {
                result[name] = type
            }
        }
        return result
    }

    func overrideType(for deviceName: String) -> DeviceType? {
        let normalizedName = normalize(deviceName)
        guard !normalizedName.isEmpty else { return nil }
        let raw = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        guard let typeRawValue = raw[normalizedName] else { return nil }
        return DeviceType(rawValue: typeRawValue)
    }

    func setOverrideType(for deviceName: String, type: DeviceType?) {
        let normalizedName = normalize(deviceName)
        guard !normalizedName.isEmpty else { return }

        var raw = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: String] ?? [:]
        if let type {
            raw[normalizedName] = type.rawValue
        } else {
            raw.removeValue(forKey: normalizedName)
        }
        UserDefaults.standard.set(raw, forKey: defaultsKey)

        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    private func normalize(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }
}
