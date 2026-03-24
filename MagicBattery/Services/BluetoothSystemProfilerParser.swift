import Foundation

struct BluetoothSystemProfilerAccessory: Equatable {
    let uniqueKey: String
    let name: String
    let normalizedName: String
    let batteryLevel: Int
    let type: DeviceType
    let parentUniqueKey: String?
}

enum BluetoothSystemProfilerParser {
    static func parse(_ output: String) -> [BluetoothSystemProfilerAccessory] {
        let lines = output.components(separatedBy: .newlines)
        var accessories: [BluetoothSystemProfilerAccessory] = []
        var inConnectedSection = false
        var currentName: String?
        var currentFields: [String: String] = [:]
        var currentIndent = Int.max

        func flushCurrent() {
            guard let currentName else { return }
            let normalizedName = normalizeDeviceName(currentName)
            let address = currentFields["Address"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let serial = currentFields["Serial Number"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let uniqueKey = serial ?? address ?? normalizedName
            let minorType = currentFields["Minor Type"]?.lowercased() ?? ""

            let left = parsePercent(currentFields["Left Battery Level"])
            let right = parsePercent(currentFields["Right Battery Level"])
            let chargingCase = parsePercent(currentFields["Case Battery Level"])
            let overall = parsePercent(currentFields["Battery Level"])
            let hasSplitBattery = left != nil || right != nil || chargingCase != nil
            let isHeadphoneLike = minorType.contains("headphone") || minorType.contains("headset") || minorType.contains("earbud")
            let baseType: DeviceType = hasSplitBattery ? .airPods : determineDeviceType(fromName: currentName)

            if hasSplitBattery {
                if let left {
                    accessories.append(
                        BluetoothSystemProfilerAccessory(
                            uniqueKey: "\(uniqueKey)::left",
                            name: "\(currentName) · \(String(localized: "device.type.airpods_left"))",
                            normalizedName: normalizedName,
                            batteryLevel: left,
                            type: .airPodsLeft,
                            parentUniqueKey: uniqueKey
                        )
                    )
                }
                if let right {
                    accessories.append(
                        BluetoothSystemProfilerAccessory(
                            uniqueKey: "\(uniqueKey)::right",
                            name: "\(currentName) · \(String(localized: "device.type.airpods_right"))",
                            normalizedName: normalizedName,
                            batteryLevel: right,
                            type: .airPodsRight,
                            parentUniqueKey: uniqueKey
                        )
                    )
                }
                if let chargingCase {
                    accessories.append(
                        BluetoothSystemProfilerAccessory(
                            uniqueKey: "\(uniqueKey)::case",
                            name: "\(currentName) · \(String(localized: "device.type.airpods_case"))",
                            normalizedName: normalizedName,
                            batteryLevel: chargingCase,
                            type: .airPodsCase,
                            parentUniqueKey: uniqueKey
                        )
                    )
                }
            } else if let overall {
                accessories.append(
                    BluetoothSystemProfilerAccessory(
                        uniqueKey: uniqueKey,
                        name: currentName,
                        normalizedName: normalizedName,
                        batteryLevel: overall,
                        type: baseType,
                        parentUniqueKey: nil
                    )
                )
            } else if isHeadphoneLike {
                accessories.append(
                    BluetoothSystemProfilerAccessory(
                        uniqueKey: uniqueKey,
                        name: currentName,
                        normalizedName: normalizedName,
                        batteryLevel: -1,
                        type: baseType,
                        parentUniqueKey: nil
                    )
                )
            }
        }

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed == "Connected:" {
                flushCurrent()
                inConnectedSection = true
                currentName = nil
                currentFields = [:]
                currentIndent = Int.max
                continue
            }

            if trimmed == "Not Connected:" {
                flushCurrent()
                inConnectedSection = false
                currentName = nil
                currentFields = [:]
                continue
            }

            guard inConnectedSection else { continue }

            let indent = rawLine.prefix { $0 == " " || $0 == "\t" }.count
            if trimmed.hasSuffix(":") && !trimmed.contains(": ") {
                flushCurrent()
                currentName = String(trimmed.dropLast())
                currentFields = [:]
                currentIndent = indent
                continue
            }

            guard currentName != nil else { continue }
            guard let separatorRange = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            currentFields[key] = value
        }

        flushCurrent()
        return accessories
    }

    private static func parsePercent(_ value: String?) -> Int? {
        guard let value else { return nil }
        let digits = value.filter { $0.isNumber }
        guard let level = Int(digits) else { return nil }
        return max(-1, min(100, level))
    }

    private static func normalizeDeviceName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }

    private static func determineDeviceType(fromName name: String) -> DeviceType {
        let normalizedName = normalizeDeviceName(name)
        if normalizedName.contains("airpods") {
            return .airPods
        }
        if normalizedName.contains("beats") || normalizedName.contains("buds") {
            return .bluetoothHeadphone
        }
        return .bluetoothDevice
    }
}
