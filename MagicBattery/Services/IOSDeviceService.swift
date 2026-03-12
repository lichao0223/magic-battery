import Foundation
import Combine

/// 通过 libimobiledevice 工具链发现已信任的 iPhone / iPad，并在可用时经 iPhone 读取 Apple Watch 电量。
final class IOSDeviceService: DeviceManager {
    private var _devices: [Device] = []
    private let devicesSubject = CurrentValueSubject<[Device], Never>([])
    private let toolRunner: IDeviceToolRunning
    private let diagnosticsProbe: IDeviceDiagnosticsProbe
    private var timer: Timer?
    private var cachedDevicesByExternalID: [String: Device] = [:]
    private var hasLoggedMissingCoreTools = false
    private var hasLoggedToolPaths = false
    private let refreshStateLock = NSLock()
    private var isRefreshInFlight = false
    private var hasPendingRefreshRequest = false
    private var eventMonitor: IOSDeviceEventMonitor?

    private let stateLock = NSLock()

    private func withLockedState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    init(toolRunner: IDeviceToolRunning = IDeviceToolRunner()) {
        self.toolRunner = toolRunner
        self.diagnosticsProbe = IDeviceDiagnosticsProbe(toolRunner: toolRunner)
    }

    deinit {
        stopMonitoring()
    }

    var devices: [Device] {
        withLockedState { _devices }
    }

    var devicesPublisher: AnyPublisher<[Device], Never> {
        devicesSubject.eraseToAnyPublisher()
    }

    func startMonitoring() {
        log("startMonitoring interval=\(Int(refreshInterval))s discovery=\(isDiscoveryEnabled) watch=\(isWatchDiscoveryEnabled) showOffline=\(shouldShowOfflineDevices)")

        // 启动 USB 设备事件监听
        eventMonitor = IOSDeviceEventMonitor { [weak self] in
            Task {
                await self?.refreshDevices()
            }
        }
        eventMonitor?.startMonitoring()

        Task {
            await refreshDevices()
        }

        // 降低轮询频率到 3 分钟作为兜底
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshDevices()
            }
        }
    }

    func stopMonitoring() {
        log("stopMonitoring")
        eventMonitor?.stopMonitoring()
        eventMonitor = nil
        timer?.invalidate()
        timer = nil
    }

    func refreshDevices() async {
        guard beginRefreshCycle() else {
            log("refresh requested while previous cycle is still running; queued")
            return
        }
        defer {
            if finishRefreshCycle() {
                log("running queued refresh cycle")
                Task { [weak self] in
                    await self?.refreshDevices()
                }
            }
        }

        log("refresh begin discovery=\(isDiscoveryEnabled) watch=\(isWatchDiscoveryEnabled) showOffline=\(shouldShowOfflineDevices)")
        guard isDiscoveryEnabled else {
            log("discovery disabled by settings")
            publish(devices: [])
            return
        }

        logToolPathsIfNeeded()

        guard hasCoreTools else {
            if !hasLoggedMissingCoreTools {
                hasLoggedMissingCoreTools = true
                logMissingTools()
            }
            publish(devices: [])
            return
        }

        hasLoggedMissingCoreTools = false

        let usbIDs = await fetchDeviceIDs(network: false)
        log("usb discovered count=\(usbIDs.count) ids=\(usbIDs)")
        for udid in usbIDs {
            await enableWiFiConnectionsIfPossible(for: udid)
        }

        let networkIDs = await fetchDeviceIDs(network: true)
        log("network discovered count=\(networkIDs.count) ids=\(networkIDs)")
        var sourceByUDID: [String: DeviceSource] = [:]
        for udid in networkIDs {
            sourceByUDID[udid] = .libimobiledeviceNetwork
        }
        for udid in usbIDs {
            sourceByUDID[udid] = .libimobiledeviceUSB
        }

        var freshDevices: [Device] = []
        for udid in sourceByUDID.keys.sorted() {
            guard let source = sourceByUDID[udid] else { continue }
            let discovered = await fetchDevices(for: udid, source: source)
            freshDevices.append(contentsOf: discovered)
        }
        log("fresh device models count=\(freshDevices.count) summary=\(deviceSummary(freshDevices))")

        let previousCache = withLockedState { cachedDevicesByExternalID }
        var nextCache: [String: Device] = [:]
        for device in freshDevices {
            if let externalIdentifier = device.externalIdentifier {
                nextCache[externalIdentifier] = device
            }
        }

        if shouldShowOfflineDevices {
            let freshExternalIDs = Set(nextCache.keys)
            let staleDevices = previousCache.values
                .filter { device in
                    guard let externalIdentifier = device.externalIdentifier else { return false }
                    return !freshExternalIDs.contains(externalIdentifier)
                }
                .map(makeStaleDevice(from:))
            freshDevices.append(contentsOf: staleDevices)
            if !staleDevices.isEmpty {
                log("stale devices appended count=\(staleDevices.count) summary=\(deviceSummary(staleDevices))")
            }
        }

        withLockedState {
            cachedDevicesByExternalID = previousCache.merging(nextCache) { _, new in new }
        }
        publish(devices: freshDevices.sorted { sortDevices(lhs: $0, rhs: $1) })
        log("refresh end published count=\(devices.count) summary=\(deviceSummary(devices))")
    }

    func getDevice(by id: UUID) -> Device? {
        withLockedState {
            _devices.first(where: { $0.id == id })
        }
    }

    private var hasCoreTools: Bool {
        toolRunner.isAvailable(.ideviceID) && toolRunner.isAvailable(.ideviceInfo)
    }

    private var refreshInterval: TimeInterval {
        let configured = UserDefaults.standard.integer(forKey: "updateInterval")
        if configured > 0 {
            // iOS 设备刷新使用更长的间隔（3 倍），因为有事件驱动兜底
            return TimeInterval(max(90, configured * 3))
        }
        return 180  // 默认 3 分钟
    }

    private var isDiscoveryEnabled: Bool {
        UserDefaults.standard.object(forKey: "enableIDeviceDiscovery") as? Bool ?? true
    }

    private var isWatchDiscoveryEnabled: Bool {
        UserDefaults.standard.object(forKey: "enableWatchBatteryDiscovery") as? Bool ?? true
    }

    private var shouldShowOfflineDevices: Bool {
        UserDefaults.standard.object(forKey: "showOfflineIDevices") as? Bool ?? true
    }

    private func publish(devices: [Device]) {
        withLockedState {
            _devices = devices
        }
        devicesSubject.send(devices)
    }

    private func fetchDeviceIDs(network: Bool) async -> [String] {
        let arguments = network ? ["-n"] : ["-l"]
        log("scan \(network ? "network" : "usb") start args=\(arguments)")
        let result = await toolRunner.run(.ideviceID, arguments: arguments, timeout: 8)
        switch result {
        case .success(let output):
            let ids = IDeviceParser.parseDeviceIDs(from: output.stdout)
            log("scan \(network ? "network" : "usb") raw=\(sanitize(output.stdout)) parsed=\(ids)")
            return ids
        case .failure(let error):
            log("scan \(network ? "network" : "usb") failed: \(error.localizedDescription)")
            return []
        }
    }

    private func enableWiFiConnectionsIfPossible(for udid: String) async {
        guard toolRunner.isAvailable(.wifiConnection) else {
            log("skip wifi bootstrap for \(udid): wificonnection not available")
            return
        }

        log("enabling wifi connections for udid=\(udid)")

        let result = await toolRunner.run(
            .wifiConnection,
            arguments: ["-u", udid, "true"],
            timeout: 8
        )

        switch result {
        case .success(let output):
            log("wifi bootstrap success for \(udid): \(sanitize(output.stdout))")
        case .failure(let error):
            log("wifi bootstrap failed for \(udid): \(error.localizedDescription)")
        }
    }

    private func fetchDevices(for udid: String, source: DeviceSource) async -> [Device] {
        log("fetch device begin udid=\(udid) source=\(source.rawValue)")
        guard let infoRecord = await fetchDeviceInfo(udid: udid, source: source) else {
            log("fetch device aborted udid=\(udid): device info unavailable")
            return []
        }

        let batteryFetch = await fetchBatteryInfo(udid: udid, source: source)
        let lastUpdated = Date()
        let resolvedType = deviceType(for: infoRecord)
        var devices = [
            Device(
                id: StableDeviceIDStore.shared.id(namespace: "idevice", key: udid),
                name: infoRecord.deviceName,
                type: resolvedType,
                batteryLevel: batteryFetch?.record?.level ?? -1,
                isCharging: batteryFetch?.record?.isCharging ?? false,
                lastUpdated: lastUpdated,
                externalIdentifier: udid,
                source: source
            )
        ]
        log("device built udid=\(udid) name=\(infoRecord.deviceName) type=\(resolvedType.rawValue) battery=\(batteryFetch?.record?.level ?? -1) charging=\(batteryFetch?.record?.isCharging ?? false)")

        if let batteryFetch {
            await diagnosticsProbe.probePhoneIfNeeded(
                udid: udid,
                source: source,
                info: infoRecord,
                batteryFetch: batteryFetch
            )
        }

        if isWatchDiscoveryEnabled,
           resolvedType == .iPhone,
           let watch = await fetchWatch(
            for: udid,
            parentName: infoRecord.deviceName,
            lastUpdated: lastUpdated
           ) {
            devices.append(watch)
            log("watch attached phone=\(udid) watch=\(watch.name) battery=\(watch.batteryLevel)")
        } else if isWatchDiscoveryEnabled, resolvedType == .iPhone {
            log("watch lookup returned no result for phone=\(udid)")
        }

        return devices
    }

    private func fetchDeviceInfo(udid: String, source: DeviceSource) async -> IDeviceInfoRecord? {
        let result = await toolRunner.run(
            .ideviceInfo,
            arguments: connectionArguments(for: source) + ["-u", udid],
            timeout: 10
        )

        switch result {
        case .success(let output):
            let parsed = IDeviceParser.parseDeviceInfo(from: output.stdout, udid: udid)
            if let parsed {
                log("device info udid=\(udid) source=\(source.rawValue) name=\(parsed.deviceName) class=\(parsed.deviceClass) product=\(parsed.productType)")
            } else {
                log("device info parse failed udid=\(udid) raw=\(sanitize(output.stdout))")
            }
            return parsed
        case .failure(let error):
            log("device info command failed udid=\(udid): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchBatteryInfo(udid: String, source: DeviceSource) async -> IDeviceBatteryFetchResult? {
        let result = await toolRunner.run(
            .ideviceInfo,
            arguments: connectionArguments(for: source) + ["-u", udid, "-q", "com.apple.mobile.battery"],
            timeout: 10
        )

        switch result {
        case .success(let output):
            let parsed = IDeviceParser.parseBatteryInfo(from: output.stdout)
            if let parsed {
                log("battery info udid=\(udid) level=\(parsed.level) charging=\(parsed.isCharging)")
            } else {
                log("battery parse failed udid=\(udid) raw=\(sanitize(output.stdout))")
            }
            return IDeviceBatteryFetchResult(record: parsed, rawOutput: output.stdout)
        case .failure(let error):
            log("battery command failed udid=\(udid): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchWatch(for phoneUDID: String, parentName: String, lastUpdated: Date) async -> Device? {
        guard toolRunner.isAvailable(.companionTest) else {
            log("skip watch lookup for phone=\(phoneUDID): comptest not available")
            return nil
        }

        log("watch lookup start phone=\(phoneUDID)")
        let result = await toolRunner.run(.companionTest, arguments: [phoneUDID], timeout: 12)
        switch result {
        case .success(let output):
            await diagnosticsProbe.probeWatchIfNeeded(phoneUDID: phoneUDID, output: output.stdout)
            guard let record = IDeviceParser.parseWatchInfo(from: output.stdout) else {
                log("watch parse failed phone=\(phoneUDID) raw=\(sanitize(output.stdout))")
                return nil
            }

            log("watch info phone=\(phoneUDID) watchID=\(record.watchID) name=\(record.deviceName) level=\(record.level) charging=\(record.isCharging)")
            return Device(
                id: StableDeviceIDStore.shared.id(namespace: "watch", key: record.watchID),
                name: record.deviceName,
                type: .appleWatch,
                batteryLevel: record.level,
                isCharging: record.isCharging,
                lastUpdated: lastUpdated,
                externalIdentifier: record.watchID,
                parentExternalIdentifier: phoneUDID,
                source: .companionProxy,
                detailText: parentName
            )
        case .failure(let error):
            log("watch command failed phone=\(phoneUDID): \(error.localizedDescription)")
            return nil
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

    private func deviceType(for record: IDeviceInfoRecord) -> DeviceType {
        switch record.deviceClass.lowercased() {
        case "iphone":
            return .iPhone
        case "ipad":
            return .iPad
        default:
            if record.productType.lowercased().hasPrefix("iphone") {
                return .iPhone
            }
            if record.productType.lowercased().hasPrefix("ipad") {
                return .iPad
            }
            return .bluetoothDevice
        }
    }

    private func makeStaleDevice(from device: Device) -> Device {
        Device(
            id: device.id,
            name: device.name,
            type: device.type,
            batteryLevel: device.batteryLevel,
            isCharging: device.isCharging,
            lastUpdated: device.lastUpdated,
            externalIdentifier: device.externalIdentifier,
            parentExternalIdentifier: device.parentExternalIdentifier,
            source: device.source,
            detailText: String(localized: "device.stale_detail"),
            isStale: true
        )
    }

    private func sortDevices(lhs: Device, rhs: Device) -> Bool {
        if lhs.isStale != rhs.isStale {
            return !lhs.isStale
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private func logToolPathsIfNeeded() {
        guard !hasLoggedToolPaths else { return }
        hasLoggedToolPaths = true

        for tool in IDeviceTool.allCases {
            log("tool \(tool.executableName) path=\(toolRunner.resolvedPath(for: tool) ?? "nil")")
        }
    }

    private func logMissingTools() {
        let tools = [IDeviceTool.ideviceID, .ideviceInfo, .ideviceDiagnostics, .wifiConnection, .companionTest, .watchRegistryProbe]
        for tool in tools {
            log("missing tool \(tool.executableName) path=nil candidates=\(toolRunner.candidatePaths(for: tool))")
        }
        log("libimobiledevice tools not found; skipping iPhone/iPad discovery")
    }

    private func deviceSummary(_ devices: [Device]) -> String {
        if devices.isEmpty {
            return "[]"
        }
        return devices.map { device in
            let battery = device.isBatteryUnknown ? "unknown" : "\(device.batteryLevel)%"
            return "\(device.name){type=\(device.type.rawValue),source=\(device.source.rawValue),battery=\(battery),stale=\(device.isStale)}"
        }.joined(separator: ", ")
    }

    private func sanitize(_ text: String, limit: Int = 220) -> String {
        let compact = text.replacingOccurrences(of: "\n", with: "\\n")
        guard compact.count > limit else { return compact }
        return String(compact.prefix(limit)) + "..."
    }

    private func log(_ message: String) {
        AppLogger.debug(message, category: AppLogger.ios)
    }

    private func beginRefreshCycle() -> Bool {
        refreshStateLock.lock()
        defer { refreshStateLock.unlock() }

        if isRefreshInFlight {
            hasPendingRefreshRequest = true
            return false
        }

        isRefreshInFlight = true
        return true
    }

    private func finishRefreshCycle() -> Bool {
        refreshStateLock.lock()
        defer { refreshStateLock.unlock() }

        isRefreshInFlight = false
        let shouldRunAgain = hasPendingRefreshRequest
        hasPendingRefreshRequest = false
        return shouldRunAgain
    }
}
