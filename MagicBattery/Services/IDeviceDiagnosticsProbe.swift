import Foundation

struct IDeviceBatteryFetchResult {
    let record: IDeviceBatteryRecord?
    let rawOutput: String
}

/// 实验性探针：尽可能记录 iPhone / Apple Watch 可访问的电池诊断原始输出。
final class IDeviceDiagnosticsProbe {
    private let toolRunner: IDeviceToolRunning
    private let stateLock = NSLock()
    private var probedPhoneIDs: Set<String> = []
    private var probedWatchPhoneIDs: Set<String> = []

    init(toolRunner: IDeviceToolRunning) {
        self.toolRunner = toolRunner
    }

    func probePhoneIfNeeded(
        udid: String,
        source: DeviceSource,
        info: IDeviceInfoRecord,
        batteryFetch: IDeviceBatteryFetchResult
    ) async {
        guard markPhoneAsProbed(udid) else { return }

        log("phone probe begin udid=\(udid) name=\(info.deviceName) product=\(info.productType) source=\(source.rawValue)")
        logKeyValueOutput(
            title: "lockdown com.apple.mobile.battery udid=\(udid)",
            output: batteryFetch.rawOutput
        )

        let batteryXML = await toolRunner.run(
            .ideviceInfo,
            arguments: connectionArguments(for: source) + ["-u", udid, "-q", "com.apple.mobile.battery", "-x"],
            timeout: 10
        )
        logExecutionResult(batteryXML, label: "lockdown battery xml udid=\(udid)")

        guard toolRunner.isAvailable(.ideviceDiagnostics) else {
            log("deep phone diagnostics skipped udid=\(udid): idevicediagnostics not available")
            return
        }

        let gestaltKeys = [
            "BatteryCurrentCapacity",
            "BatteryIsCharging",
            "BatteryIsFullyCharged",
            "BatteryCycleCount",
            "BatteryMaximumCapacityPercent",
            "BatterySerialNumber"
        ]

        let probes: [(label: String, arguments: [String])] = [
            (
                "diagnostics GasGauge udid=\(udid)",
                connectionArguments(for: source) + ["-u", udid, "diagnostics", "GasGauge"]
            ),
            (
                "ioregentry AppleSmartBattery udid=\(udid)",
                connectionArguments(for: source) + ["-u", udid, "ioregentry", "AppleSmartBattery"]
            ),
            (
                "ioregentry AppleARMPMUCharger udid=\(udid)",
                connectionArguments(for: source) + ["-u", udid, "ioregentry", "AppleARMPMUCharger"]
            ),
            (
                "mobilegestalt battery keys udid=\(udid)",
                connectionArguments(for: source) + ["-u", udid, "mobilegestalt"] + gestaltKeys
            )
        ]

        for probe in probes {
            let result = await toolRunner.run(.ideviceDiagnostics, arguments: probe.arguments, timeout: 12)
            logExecutionResult(result, label: probe.label)
        }
    }

    func probeWatchIfNeeded(phoneUDID: String, output: String) async {
        guard markWatchAsProbed(phoneUDID) else { return }

        log("watch probe begin phone=\(phoneUDID)")
        logRawOutput(title: "comptest raw phone=\(phoneUDID)", output: output)

        let parsedValues = IDeviceParser.parseKeyValuePairs(from: output)
        if parsedValues.isEmpty {
            log("watch probe parsed no key-values phone=\(phoneUDID)")
        } else {
            log("watch probe parsed keys phone=\(phoneUDID) keys=\(parsedValues.keys.sorted())")
        }

        guard toolRunner.isAvailable(.watchRegistryProbe) else {
            log("watch deep diagnostics skipped phone=\(phoneUDID): watchregistryprobe not available")
            return
        }

        let result = await toolRunner.run(.watchRegistryProbe, arguments: [phoneUDID], timeout: 12)
        logExecutionResult(result, label: "watch registry probe phone=\(phoneUDID)")
    }

    private func markPhoneAsProbed(_ udid: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        return probedPhoneIDs.insert(udid).inserted
    }

    private func markWatchAsProbed(_ phoneUDID: String) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        return probedWatchPhoneIDs.insert(phoneUDID).inserted
    }

    private func connectionArguments(for source: DeviceSource) -> [String] {
        switch source {
        case .libimobiledeviceNetwork:
            return ["-n"]
        default:
            return []
        }
    }

    private func logExecutionResult(_ result: Result<ToolExecutionResult, Error>, label: String) {
        switch result {
        case .success(let output):
            logRawOutput(title: label, output: output.stdout)
            if !output.stderr.isEmpty {
                logRawOutput(title: "\(label) stderr", output: output.stderr)
            }
        case .failure(let error):
            log("probe command failed \(label): \(error.localizedDescription)")
        }
    }

    private func logKeyValueOutput(title: String, output: String) {
        let values = IDeviceParser.parseKeyValuePairs(from: output)
        if values.isEmpty {
            log("probe \(title): no key-values parsed")
            logRawOutput(title: title, output: output)
            return
        }

        let body = values.keys.sorted().map { key in
            "\(key): \(values[key] ?? "")"
        }.joined(separator: "\n")
        logBlock(title: title, body: body)
    }

    private func logRawOutput(title: String, output: String) {
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log("probe \(title): <empty>")
            return
        }

        logBlock(title: title, body: output)
    }

    private func logBlock(title: String, body: String) {
        AppLogger.debug(">>> \(title)", category: AppLogger.ios)
        AppLogger.debug(body, category: AppLogger.ios)
        AppLogger.debug("<<< \(title)", category: AppLogger.ios)
    }

    private func log(_ message: String) {
        AppLogger.debug(message, category: AppLogger.ios)
    }
}
