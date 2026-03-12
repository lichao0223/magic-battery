import Foundation
import IOKit
import IOKit.ps

enum DeviceDetailsError: LocalizedError {
    case unsupportedDevice(DeviceType)
    case missingIdentifier
    case noDetailsAvailable
    case plistParseFailed
    case macBatteryUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedDevice(let type):
            return String(format: String(localized: "error.unsupported_device"), type.displayName)
        case .missingIdentifier:
            return String(localized: "error.missing_identifier")
        case .noDetailsAvailable:
            return String(localized: "error.no_details")
        case .plistParseFailed:
            return String(localized: "error.plist_parse")
        case .macBatteryUnavailable:
            return String(localized: "error.mac_battery_unavailable")
        }
    }
}

final class DeviceDetailsService {
    private let toolRunner: IDeviceToolRunning

    init(toolRunner: IDeviceToolRunning = IDeviceToolRunner()) {
        self.toolRunner = toolRunner
    }

    func loadDetails(for device: Device) async throws -> DeviceDetailSnapshot {
        log("load begin name=\(device.name) type=\(device.type.rawValue) source=\(device.source.rawValue)")
        do {
            let snapshot: DeviceDetailSnapshot
            switch device.type {
            case .iPhone, .iPad:
                snapshot = try await loadIDeviceDetails(for: device)
            case .appleWatch:
                snapshot = try await loadWatchDetails(for: device)
            case .mac:
                snapshot = try loadMacDetails(for: device)
            default:
                throw DeviceDetailsError.unsupportedDevice(device.type)
            }

            log("load success name=\(device.name) sections=\(snapshot.sections.count)")
            return snapshot
        } catch {
            log("load failed name=\(device.name) error=\(error.localizedDescription)")
            throw error
        }
    }

    private func loadIDeviceDetails(for device: Device) async throws -> DeviceDetailSnapshot {
        guard let udid = device.externalIdentifier else {
            throw DeviceDetailsError.missingIdentifier
        }

        let infoOutput = try await execute(
            .ideviceInfo,
            arguments: connectionArguments(for: device.source) + ["-u", udid],
            timeout: 10
        )
        let infoValues = IDeviceParser.parseKeyValuePairs(from: infoOutput.stdout)

        let batteryOutput = try await execute(
            .ideviceInfo,
            arguments: connectionArguments(for: device.source) + ["-u", udid, "-q", "com.apple.mobile.battery"],
            timeout: 10
        )
        let batteryValues = IDeviceParser.parseKeyValuePairs(from: batteryOutput.stdout)

        var notes: [String] = []
        let gasGauge = await optionalPlistDictionary(
            tool: .ideviceDiagnostics,
            arguments: connectionArguments(for: device.source) + ["-u", udid, "diagnostics", "GasGauge"],
            rootKey: "GasGauge",
            timeout: 12,
            failureNote: String(localized: "footnote.gasgauge_unavailable"),
            notes: &notes
        )
        let smartBattery = await optionalPlistDictionary(
            tool: .ideviceDiagnostics,
            arguments: connectionArguments(for: device.source) + ["-u", udid, "ioregentry", "AppleSmartBattery"],
            rootKey: "IORegistry",
            timeout: 12,
            failureNote: String(localized: "footnote.smartbattery_unavailable"),
            notes: &notes
        )

        let currentItems = compactItems([
            metricItem(id: "level", title: String(localized: "detail.level"), value: percentString(intValue(forKey: "BatteryCurrentCapacity", in: batteryValues)) ?? percentString(device.batteryLevel)),
            metricItem(id: "charging", title: String(localized: "detail.charging"), value: boolString(boolValue(forKey: "BatteryIsCharging", in: batteryValues) ?? device.isCharging)),
            metricItem(id: "external_connected", title: String(localized: "detail.external_connected"), value: boolString(boolValue(forKey: "ExternalConnected", in: batteryValues) ?? boolValue(forKey: "ExternalConnected", in: smartBattery))),
            metricItem(id: "charge_capable", title: String(localized: "detail.charge_capable"), value: boolString(boolValue(forKey: "ExternalChargeCapable", in: batteryValues) ?? boolValue(forKey: "ExternalChargeCapable", in: smartBattery))),
            metricItem(id: "fully_charged", title: String(localized: "detail.fully_charged"), value: boolString(boolValue(forKey: "FullyCharged", in: batteryValues) ?? boolValue(forKey: "FullyCharged", in: smartBattery))),
            metricItem(id: "has_battery", title: String(localized: "detail.has_battery"), value: boolString(boolValue(forKey: "HasBattery", in: batteryValues)))
        ])

        let designCapacity = intValue(forKey: "DesignCapacity", in: smartBattery) ?? intValue(forKey: "DesignCapacity", in: gasGauge)
        let nominalCapacity = intValue(forKey: "NominalChargeCapacity", in: smartBattery)
        let rawCurrentCapacity = intValue(forKey: "AppleRawCurrentCapacity", in: smartBattery)
        let remainingCapacity = intValue(at: ["BatteryData", "TrueRemainingCapacity"], in: smartBattery)
        let healthEstimate = healthEstimatePercent(currentCapacity: nominalCapacity, designCapacity: designCapacity)

        let capacityItems = compactItems([
            metricItem(id: "cycle_count", title: String(localized: "detail.cycle_count"), value: integerString(intValue(forKey: "CycleCount", in: smartBattery) ?? intValue(forKey: "CycleCount", in: gasGauge))),
            metricItem(id: "health_estimate", title: String(localized: "detail.health_estimate"), value: percentString(healthEstimate), detail: String(localized: "detail.health_estimate_note")),
            metricItem(id: "design_capacity", title: String(localized: "detail.design_capacity"), value: capacityString(designCapacity)),
            metricItem(id: "nominal_capacity", title: String(localized: "detail.nominal_capacity"), value: capacityString(nominalCapacity)),
            metricItem(id: "raw_current_capacity", title: String(localized: "detail.raw_current_capacity"), value: capacityString(rawCurrentCapacity)),
            metricItem(id: "true_remaining_capacity", title: String(localized: "detail.true_remaining"), value: capacityString(remainingCapacity)),
            metricItem(id: "absolute_capacity", title: String(localized: "detail.absolute_capacity"), value: capacityString(intValue(forKey: "AbsoluteCapacity", in: smartBattery))),
            metricItem(id: "battery_serial", title: String(localized: "detail.battery_serial"), value: stringValue(forKey: "Serial", in: smartBattery) ?? stringValue(at: ["BatteryData", "Serial"], in: smartBattery))
        ])

        let telemetryItems = compactItems([
            metricItem(id: "voltage", title: String(localized: "detail.voltage"), value: measurementString(intValue(forKey: "Voltage", in: smartBattery), unit: "mV")),
            metricItem(id: "raw_voltage", title: String(localized: "detail.raw_voltage"), value: measurementString(intValue(forKey: "AppleRawBatteryVoltage", in: smartBattery), unit: "mV")),
            metricItem(id: "instant_amperage", title: String(localized: "detail.instant_amperage"), value: measurementString(intValue(forKey: "InstantAmperage", in: smartBattery), unit: "mA")),
            metricItem(id: "amperage", title: String(localized: "detail.average_amperage"), value: measurementString(intValue(forKey: "Amperage", in: smartBattery), unit: "mA")),
            metricItem(id: "temperature", title: String(localized: "detail.temperature"), value: temperatureString(intValue(forKey: "Temperature", in: smartBattery))),
            metricItem(id: "virtual_temperature", title: String(localized: "detail.virtual_temperature"), value: temperatureString(intValue(forKey: "VirtualTemperature", in: smartBattery))),
            metricItem(id: "battery_power", title: String(localized: "detail.battery_power"), value: powerMilliwattString(intValue(at: ["PowerTelemetryData", "BatteryPower"], in: smartBattery))),
            metricItem(id: "health_metric", title: String(localized: "detail.health_metric"), value: integerString(intValue(at: ["BatteryData", "BatteryHealthMetric"], in: smartBattery)), detail: String(localized: "detail.health_metric_note"))
        ])

        let chargerItems = compactItems([
            metricItem(id: "charging_current", title: String(localized: "detail.charging_current"), value: measurementString(intValue(at: ["ChargerData", "ChargingCurrent"], in: smartBattery), unit: "mA")),
            metricItem(id: "charging_voltage", title: String(localized: "detail.charging_voltage"), value: measurementString(intValue(at: ["ChargerData", "ChargingVoltage"], in: smartBattery), unit: "mV")),
            metricItem(id: "adapter_voltage", title: String(localized: "detail.adapter_voltage"), value: measurementString(intValue(at: ["AdapterDetails", "AdapterVoltage"], in: smartBattery), unit: "mV")),
            metricItem(id: "adapter_current", title: String(localized: "detail.adapter_current"), value: measurementString(intValue(at: ["AdapterDetails", "Current"], in: smartBattery), unit: "mA")),
            metricItem(id: "time_remaining", title: String(localized: "detail.time_remaining"), value: durationString(seconds: intValue(forKey: "TimeRemaining", in: smartBattery) ?? intValue(forKey: "AvgTimeToEmpty", in: smartBattery))),
            metricItem(id: "not_charging_reason", title: String(localized: "detail.not_charging_reason"), value: integerString(intValue(at: ["ChargerData", "NotChargingReason"], in: smartBattery)))
        ])

        let metadataItems = compactItems([
            metricItem(id: "device_name", title: String(localized: "detail.device_name"), value: infoValues["DeviceName"] ?? device.name),
            metricItem(id: "product_type", title: String(localized: "detail.product_type"), value: infoValues["ProductType"]),
            metricItem(id: "hardware_model", title: String(localized: "detail.hardware_model"), value: infoValues["HardwareModel"]),
            metricItem(id: "product_version", title: String(localized: "detail.system_version"), value: infoValues["ProductVersion"]),
            metricItem(id: "build_version", title: String(localized: "detail.build_version"), value: infoValues["BuildVersion"]),
            metricItem(id: "serial_number", title: String(localized: "detail.serial_number"), value: infoValues["SerialNumber"]),
            metricItem(id: "connection", title: String(localized: "detail.connection"), value: device.sourceLabel ?? String(localized: "detail.local")),
            metricItem(id: "identifier", title: String(localized: "detail.identifier"), value: udid),
            metricItem(id: "last_updated", title: String(localized: "detail.last_updated"), value: timestampString(device.lastUpdated))
        ])

        let sections = compactSections([
            DeviceDetailSection(id: "current", title: String(localized: "section.current_status"), items: currentItems),
            DeviceDetailSection(id: "capacity", title: String(localized: "section.capacity"), items: capacityItems),
            DeviceDetailSection(id: "telemetry", title: String(localized: "section.telemetry"), items: telemetryItems),
            DeviceDetailSection(id: "charger", title: String(localized: "section.charger"), items: chargerItems),
            DeviceDetailSection(id: "metadata", title: String(localized: "section.device_info"), items: metadataItems)
        ])

        guard !sections.isEmpty else {
            throw DeviceDetailsError.noDetailsAvailable
        }

        let subtitleParts = compactStrings([
            infoValues["ProductType"],
            device.sourceLabel
        ])

        let footnoteLines = [String(localized: "footnote.idevice")] + notes

        return DeviceDetailSnapshot(
            subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · "),
            sections: sections,
            footnote: footnoteLines.joined(separator: "\n")
        )
    }

    private func loadWatchDetails(for device: Device) async throws -> DeviceDetailSnapshot {
        guard let phoneUDID = device.parentExternalIdentifier else {
            throw DeviceDetailsError.missingIdentifier
        }

        let probeOutput = try await execute(.watchRegistryProbe, arguments: [phoneUDID], timeout: 12)
        let watchBlocks = parseWatchRegistryOutput(probeOutput.stdout)
        guard let block = watchBlocks.first(where: { $0.watchID == device.externalIdentifier }) ?? watchBlocks.first else {
            throw DeviceDetailsError.noDetailsAvailable
        }

        let currentItems = compactItems([
            metricItem(id: "watch_level", title: String(localized: "detail.level"), value: block.values["BatteryCurrentCapacity"].map { "\($0)%" } ?? percentString(device.batteryLevel)),
            metricItem(id: "watch_charging", title: String(localized: "detail.charging"), value: boolString(parseBool(block.values["BatteryIsCharging"]) ?? device.isCharging))
        ])

        let metadataItems = compactItems([
            metricItem(id: "watch_name", title: String(localized: "detail.device_name"), value: block.values["DeviceName"] ?? device.name),
            metricItem(id: "watch_product", title: String(localized: "detail.product_type"), value: block.values["ProductType"]),
            metricItem(id: "watch_serial", title: String(localized: "detail.serial_number"), value: block.values["SerialNumber"]),
            metricItem(id: "watch_parent", title: String(localized: "detail.source_iphone"), value: device.detailText),
            metricItem(id: "watch_phone_identifier", title: String(localized: "detail.paired_udid"), value: phoneUDID),
            metricItem(id: "watch_identifier", title: String(localized: "detail.identifier"), value: block.watchID)
        ])

        let unsupportedKeys = block.values
            .filter { $0.value == "<unsupported>" }
            .map(\.key)
            .sorted()

        let sections = compactSections([
            DeviceDetailSection(id: "current", title: String(localized: "section.current_status"), items: currentItems),
            DeviceDetailSection(id: "metadata", title: String(localized: "section.device_info"), items: metadataItems)
        ])

        guard !sections.isEmpty else {
            throw DeviceDetailsError.noDetailsAvailable
        }

        let footnote: String?
        if unsupportedKeys.isEmpty {
            footnote = String(localized: "footnote.watch")
        } else {
            footnote = String(format: String(localized: "footnote.watch_unsupported"), unsupportedKeys.joined(separator: ", "))
        }

        return DeviceDetailSnapshot(
            subtitle: compactStrings([block.values["ProductType"], device.detailText]).joined(separator: " · "),
            sections: sections,
            footnote: footnote
        )
    }

    private func loadMacDetails(for device: Device) throws -> DeviceDetailSnapshot {
        let powerSource = try currentMacPowerSource()
        let smartBattery = try currentMacSmartBatteryProperties()

        let adapterDetails = dictionary(forKey: "AdapterDetails", in: smartBattery)
        let designCapacity = intValue(forKey: "DesignCapacity", in: smartBattery)
        let nominalCapacity = intValue(forKey: "NominalChargeCapacity", in: smartBattery)
        let healthEstimate = healthEstimatePercent(currentCapacity: nominalCapacity, designCapacity: designCapacity)

        let currentItems = compactItems([
            metricItem(id: "mac_level", title: String(localized: "detail.level"), value: percentString(device.batteryLevel)),
            metricItem(id: "mac_power_source", title: String(localized: "detail.power_source"), value: powerSource.powerSourceState),
            metricItem(id: "mac_charging", title: String(localized: "detail.charging"), value: boolString(powerSource.isCharging)),
            metricItem(id: "mac_present", title: String(localized: "detail.battery_present"), value: boolString(powerSource.isPresent)),
            metricItem(id: "mac_external", title: String(localized: "detail.external_connected"), value: boolString(boolValue(forKey: "ExternalConnected", in: smartBattery))),
            metricItem(id: "mac_charge_capable", title: String(localized: "detail.charge_capable"), value: boolString(boolValue(forKey: "ExternalChargeCapable", in: smartBattery))),
            metricItem(id: "mac_full", title: String(localized: "detail.fully_charged"), value: boolString(boolValue(forKey: "FullyCharged", in: smartBattery))),
            metricItem(id: "mac_time_remaining", title: String(localized: "detail.time_remaining"), value: durationString(minutes: powerSource.timeToEmptyMinutes)),
            metricItem(id: "mac_time_to_full", title: String(localized: "detail.time_to_full"), value: durationString(minutes: powerSource.timeToFullChargeMinutes))
        ])

        let capacityItems = compactItems([
            metricItem(id: "mac_cycle_count", title: String(localized: "detail.cycle_count"), value: integerString(intValue(forKey: "CycleCount", in: smartBattery))),
            metricItem(id: "mac_design_cycles", title: String(localized: "detail.design_cycle_limit"), value: integerString(intValue(forKey: "DesignCycleCount9C", in: smartBattery))),
            metricItem(id: "mac_health_estimate", title: String(localized: "detail.health_estimate"), value: percentString(healthEstimate), detail: String(localized: "detail.health_estimate_note")),
            metricItem(id: "mac_design_capacity", title: String(localized: "detail.design_capacity"), value: capacityString(designCapacity)),
            metricItem(id: "mac_nominal_capacity", title: String(localized: "detail.nominal_capacity"), value: capacityString(nominalCapacity)),
            metricItem(id: "mac_raw_current_capacity", title: String(localized: "detail.raw_current_capacity"), value: capacityString(intValue(forKey: "AppleRawCurrentCapacity", in: smartBattery))),
            metricItem(id: "mac_serial", title: String(localized: "detail.battery_serial"), value: stringValue(forKey: "Serial", in: smartBattery))
        ])

        let telemetryItems = compactItems([
            metricItem(id: "mac_voltage", title: String(localized: "detail.voltage"), value: measurementString(intValue(forKey: "Voltage", in: smartBattery), unit: "mV")),
            metricItem(id: "mac_raw_voltage", title: String(localized: "detail.raw_voltage"), value: measurementString(intValue(forKey: "AppleRawBatteryVoltage", in: smartBattery), unit: "mV")),
            metricItem(id: "mac_instant_amperage", title: String(localized: "detail.instant_amperage"), value: measurementString(intValue(forKey: "InstantAmperage", in: smartBattery), unit: "mA")),
            metricItem(id: "mac_amperage", title: String(localized: "detail.average_amperage"), value: measurementString(intValue(forKey: "Amperage", in: smartBattery), unit: "mA")),
            metricItem(id: "mac_temperature", title: String(localized: "detail.temperature"), value: temperatureString(intValue(forKey: "Temperature", in: smartBattery))),
            metricItem(id: "mac_virtual_temperature", title: String(localized: "detail.virtual_temperature"), value: temperatureString(intValue(forKey: "VirtualTemperature", in: smartBattery))),
            metricItem(id: "mac_battery_power", title: String(localized: "detail.battery_power"), value: powerMilliwattString(intValue(at: ["PowerTelemetryData", "BatteryPower"], in: smartBattery)))
        ])

        let adapterItems = compactItems([
            metricItem(id: "mac_adapter_description", title: String(localized: "detail.adapter_type"), value: stringValue(forKey: "Description", in: adapterDetails)),
            metricItem(id: "mac_adapter_watts", title: String(localized: "detail.adapter_power"), value: powerString(intValue(forKey: "Watts", in: adapterDetails))),
            metricItem(id: "mac_adapter_voltage", title: String(localized: "detail.adapter_voltage"), value: measurementString(intValue(forKey: "AdapterVoltage", in: adapterDetails), unit: "mV")),
            metricItem(id: "mac_adapter_current", title: String(localized: "detail.adapter_current"), value: measurementString(intValue(forKey: "Current", in: adapterDetails), unit: "mA")),
            metricItem(id: "mac_adapter_wireless", title: String(localized: "detail.wireless_charging"), value: boolString(boolValue(forKey: "IsWireless", in: adapterDetails)))
        ])

        let metadataItems = compactItems([
            metricItem(id: "mac_name", title: String(localized: "detail.device_name"), value: device.name),
            metricItem(id: "mac_identifier", title: String(localized: "detail.device_source"), value: String(localized: "detail.local")),
            metricItem(id: "mac_last_updated", title: String(localized: "detail.last_updated"), value: timestampString(device.lastUpdated))
        ])

        let sections = compactSections([
            DeviceDetailSection(id: "current", title: String(localized: "section.current_status"), items: currentItems),
            DeviceDetailSection(id: "capacity", title: String(localized: "section.capacity"), items: capacityItems),
            DeviceDetailSection(id: "telemetry", title: String(localized: "section.telemetry"), items: telemetryItems),
            DeviceDetailSection(id: "adapter", title: String(localized: "section.adapter"), items: adapterItems),
            DeviceDetailSection(id: "metadata", title: String(localized: "section.device_info"), items: metadataItems)
        ])

        guard !sections.isEmpty else {
            throw DeviceDetailsError.macBatteryUnavailable
        }

        return DeviceDetailSnapshot(
            subtitle: String(localized: "detail.subtitle_mac"),
            sections: sections,
            footnote: String(localized: "footnote.mac")
        )
    }

    private func currentMacPowerSource() throws -> MacPowerSourceSnapshot {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            throw DeviceDetailsError.macBatteryUnavailable
        }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let type = info[kIOPSTypeKey] as? String,
                  type == kIOPSInternalBatteryType else {
                continue
            }

            let powerSourceState = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue ? String(localized: "power.ac") : String(localized: "power.battery")
            let isCharging = (info[kIOPSIsChargingKey] as? Bool) ?? false
            let isPresent = (info[kIOPSIsPresentKey] as? Bool) ?? true
            let timeToEmptyMinutes = info[kIOPSTimeToEmptyKey] as? Int
            let timeToFullChargeMinutes = info[kIOPSTimeToFullChargeKey] as? Int
            return MacPowerSourceSnapshot(
                powerSourceState: powerSourceState,
                isCharging: isCharging,
                isPresent: isPresent,
                timeToEmptyMinutes: timeToEmptyMinutes,
                timeToFullChargeMinutes: timeToFullChargeMinutes
            )
        }

        throw DeviceDetailsError.macBatteryUnavailable
    }

    private func currentMacSmartBatteryProperties() throws -> [String: Any] {
        guard let matching = IOServiceMatching("AppleSmartBattery") else {
            throw DeviceDetailsError.macBatteryUnavailable
        }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else {
            throw DeviceDetailsError.macBatteryUnavailable
        }
        defer { IOObjectRelease(service) }

        var unmanagedProperties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &unmanagedProperties, kCFAllocatorDefault, 0)
        guard result == KERN_SUCCESS,
              let properties = unmanagedProperties?.takeRetainedValue() as? [String: Any] else {
            throw DeviceDetailsError.macBatteryUnavailable
        }

        return properties
    }

    private func execute(
        _ tool: IDeviceTool,
        arguments: [String],
        timeout: TimeInterval
    ) async throws -> ToolExecutionResult {
        let result = await toolRunner.run(tool, arguments: arguments, timeout: timeout)
        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    private func optionalPlistDictionary(
        tool: IDeviceTool,
        arguments: [String],
        rootKey: String,
        timeout: TimeInterval,
        failureNote: String,
        notes: inout [String]
    ) async -> [String: Any] {
        guard toolRunner.isAvailable(tool) else {
            notes.append(String(format: String(localized: "error.tool_unavailable"), tool.executableName))
            return [:]
        }

        do {
            let output = try await execute(tool, arguments: arguments, timeout: timeout)
            return try plistDictionary(from: output.stdout, rootKey: rootKey)
        } catch {
            notes.append("\(failureNote)：\(error.localizedDescription)")
            return [:]
        }
    }

    private func connectionArguments(for source: DeviceSource) -> [String] {
        switch source {
        case .libimobiledeviceNetwork:
            return ["-n"]
        default:
            return []
        }
    }

    private func plistDictionary(from output: String, rootKey: String) throws -> [String: Any] {
        guard let data = output.data(using: .utf8) else {
            throw DeviceDetailsError.plistParseFailed
        }

        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let root = plist as? [String: Any] else {
            throw DeviceDetailsError.plistParseFailed
        }

        if let nested = root[rootKey] as? [String: Any] {
            return nested
        }

        throw DeviceDetailsError.plistParseFailed
    }

    private func parseWatchRegistryOutput(_ output: String) -> [WatchRegistryBlock] {
        let lines = output.components(separatedBy: .newlines)
        var blocks: [WatchRegistryBlock] = []
        var currentWatchID: String?
        var currentLines: [String] = []

        func appendCurrentBlock() {
            guard let currentWatchID else { return }
            let values = IDeviceParser.parseKeyValuePairs(from: currentLines.joined(separator: "\n"))
            blocks.append(WatchRegistryBlock(watchID: currentWatchID, values: values))
        }

        for line in lines {
            if line.hasPrefix("Checking watch ") {
                appendCurrentBlock()
                currentWatchID = line.replacingOccurrences(of: "Checking watch ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                currentLines = []
            } else if currentWatchID != nil {
                currentLines.append(line)
            }
        }

        appendCurrentBlock()
        return blocks
    }

    private func dictionary(forKey key: String, in dictionary: [String: Any]) -> [String: Any] {
        dictionary[key] as? [String: Any] ?? [:]
    }

    private func stringValue(forKey key: String, in dictionary: [String: Any]) -> String? {
        if let value = dictionary[key] as? String, !value.isEmpty {
            return value
        }
        if let number = dictionary[key] as? NSNumber {
            return number.stringValue
        }
        return nil
    }

    private func stringValue(at path: [String], in dictionary: [String: Any]) -> String? {
        value(at: path, in: dictionary).flatMap { value in
            if let string = value as? String, !string.isEmpty {
                return string
            }
            if let number = value as? NSNumber {
                return number.stringValue
            }
            return nil
        }
    }

    private func intValue(forKey key: String, in dictionary: [String: Any]) -> Int? {
        valueToInt(dictionary[key])
    }

    private func intValue(at path: [String], in dictionary: [String: Any]) -> Int? {
        valueToInt(value(at: path, in: dictionary))
    }

    private func boolValue(forKey key: String, in dictionary: [String: Any]) -> Bool? {
        valueToBool(dictionary[key])
    }

    private func boolValue(forKey key: String, in dictionary: [String: String]) -> Bool? {
        parseBool(dictionary[key])
    }

    private func boolString(_ value: Bool?) -> String? {
        guard let value else { return nil }
        return value ? String(localized: "common.yes") : String(localized: "common.no")
    }

    private func percentString(_ value: Int?) -> String? {
        guard let value else { return nil }
        return "\(value)%"
    }

    private func capacityString(_ value: Int?) -> String? {
        measurementString(value, unit: "mAh")
    }

    private func powerString(_ value: Int?) -> String? {
        measurementString(value, unit: "W")
    }

    private func powerMilliwattString(_ value: Int?) -> String? {
        measurementString(value, unit: "mW")
    }

    private func integerString(_ value: Int?) -> String? {
        guard let value else { return nil }
        return "\(value)"
    }

    private func measurementString(_ value: Int?, unit: String) -> String? {
        guard let value else { return nil }
        return "\(value) \(unit)"
    }

    private func temperatureString(_ value: Int?) -> String? {
        guard let value else { return nil }
        return String(format: "%.2f °C", Double(value) / 100.0)
    }

    private func durationString(seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else { return nil }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: String(localized: "duration.hours_minutes"), hours, minutes)
        }
        return String(format: String(localized: "duration.minutes"), minutes)
    }

    private func durationString(minutes: Int?) -> String? {
        guard let minutes, minutes >= 0 else { return nil }
        if minutes == 0 {
            return String(format: String(localized: "duration.minutes"), 0)
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return String(format: String(localized: "duration.hours_minutes"), hours, remainingMinutes)
        }
        return String(format: String(localized: "duration.minutes"), remainingMinutes)
    }

    private func healthEstimatePercent(currentCapacity: Int?, designCapacity: Int?) -> Int? {
        guard let currentCapacity, let designCapacity, designCapacity > 0 else { return nil }
        return Int((Double(currentCapacity) / Double(designCapacity) * 100.0).rounded())
    }

    private func timestampString(_ value: Date) -> String {
        Self.timestampFormatter.string(from: value)
    }

    private func metricItem(id: String, title: String, value: String?, detail: String? = nil) -> DeviceDetailItem? {
        guard let value, !value.isEmpty else { return nil }
        return DeviceDetailItem(id: id, title: title, value: value, detail: detail)
    }

    private func compactItems(_ items: [DeviceDetailItem?]) -> [DeviceDetailItem] {
        items.compactMap { $0 }
    }

    private func compactSections(_ sections: [DeviceDetailSection]) -> [DeviceDetailSection] {
        sections.filter { !$0.items.isEmpty }
    }

    private func compactStrings(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }

    private func value(at path: [String], in dictionary: [String: Any]) -> Any? {
        var current: Any = dictionary
        for key in path {
            guard let next = (current as? [String: Any])?[key] else {
                return nil
            }
            current = next
        }
        return current
    }

    private func valueToInt(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func valueToBool(_ value: Any?) -> Bool? {
        if let bool = value as? Bool {
            return bool
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        if let string = value as? String {
            return parseBool(string)
        }
        return nil
    }

    private func parseBool(_ value: String?) -> Bool? {
        guard let value else { return nil }
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }

    private func log(_ message: String) {
        AppLogger.debug(message, category: AppLogger.ios)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct MacPowerSourceSnapshot {
    let powerSourceState: String
    let isCharging: Bool
    let isPresent: Bool
    let timeToEmptyMinutes: Int?
    let timeToFullChargeMinutes: Int?
}

private struct WatchRegistryBlock {
    let watchID: String
    let values: [String: String]
}
