import Foundation

struct IDeviceInfoRecord {
    let udid: String
    let deviceName: String
    let productType: String
    let deviceClass: String
}

struct IDeviceBatteryRecord {
    let level: Int
    let isCharging: Bool
}

struct WatchBatteryRecord {
    let watchID: String
    let deviceName: String
    let productType: String
    let level: Int
    let isCharging: Bool
}

enum IDeviceParser {
    static func parseDeviceIDs(from output: String) -> [String] {
        output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func parseDeviceInfo(from output: String, udid: String) -> IDeviceInfoRecord? {
        let values = parseKeyValueOutput(output)
        guard let deviceName = values["DeviceName"],
              let productType = values["ProductType"],
              let deviceClass = values["DeviceClass"] else {
            return nil
        }

        return IDeviceInfoRecord(
            udid: udid,
            deviceName: deviceName,
            productType: productType,
            deviceClass: deviceClass
        )
    }

    static func parseBatteryInfo(from output: String) -> IDeviceBatteryRecord? {
        let values = parseKeyValueOutput(output)
        guard let levelString = values["BatteryCurrentCapacity"],
              let level = Int(levelString) else {
            return nil
        }

        let charging = parseBool(values["BatteryIsCharging"]) ?? false
        return IDeviceBatteryRecord(level: level, isCharging: charging)
    }

    static func parseWatchInfo(from output: String) -> WatchBatteryRecord? {
        let lines = output.components(separatedBy: .newlines)
        guard let watchID = lines
            .first(where: { $0.contains("Checking watch") })?
            .components(separatedBy: " ")
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }

        let values = parseKeyValueOutput(output)
        guard let deviceName = values["DeviceName"],
              let productType = values["ProductType"],
              let levelString = values["BatteryCurrentCapacity"],
              let level = Int(levelString) else {
            return nil
        }

        let charging = parseBool(values["BatteryIsCharging"]) ?? false
        return WatchBatteryRecord(
            watchID: watchID,
            deviceName: deviceName,
            productType: productType,
            level: level,
            isCharging: charging
        )
    }

    static func parseKeyValuePairs(from output: String) -> [String: String] {
        parseKeyValueOutput(output)
    }

    private static func parseKeyValueOutput(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in output.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: ": ")
            guard parts.count >= 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1...].joined(separator: ": ").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }
            result[key] = value
        }
        return result
    }

    private static func parseBool(_ value: String?) -> Bool? {
        guard let normalized = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return nil
        }

        switch normalized {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }
}
