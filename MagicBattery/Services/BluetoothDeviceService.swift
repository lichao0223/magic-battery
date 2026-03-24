import Foundation
import Combine
import IOBluetooth
import IOKit
import IOKit.hid
import CoreBluetooth

/// 蓝牙设备服务（优化版）
/// 负责监控蓝牙设备的电池状态
final class BluetoothDeviceService: NSObject, DeviceManager {
    // MARK: - Properties

    private var _devices: [Device] = []
    private let devicesSubject = CurrentValueSubject<[Device], Never>([])
    private var timer: Timer?
    private let updateInterval: TimeInterval = 30.0 // 每30秒更新一次
    private let deviceCache: NSCache<NSString, CachedDevice> = NSCache()
    private var centralManager: CBCentralManager?
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]
    private var batteryByBLEName: [String: Int] = [:]
    private var bleCandidateNames: Set<String> = []
    private var lastBLEScanDate: Date?

    // BLE 扫描间隔配置（默认 120 秒，可通过 UserDefaults 配置）
    private var bleScanInterval: TimeInterval {
        let configured = UserDefaults.standard.integer(forKey: "bleScanInterval")
        return configured > 0 ? TimeInterval(configured) : 120.0
    }
    private let stateLock = NSLock()
    private let refreshStateLock = NSLock()
    private var isRefreshInFlight = false
    private var hasPendingRefreshRequest = false
    private let bleBatteryServiceUUID = CBUUID(string: "180F")
    private let bleBatteryLevelCharUUID = CBUUID(string: "2A19")
    #if DEBUG
    private var debugLoggedUnknownBatteryDevices = Set<String>()
    #endif

    var devices: [Device] {
        withLockedState { _devices }
    }

    var devicesPublisher: AnyPublisher<[Device], Never> {
        return devicesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupCache()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceTypeOverrideChanged),
            name: DeviceTypeOverrideStore.didChangeNotification,
            object: nil
        )
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - DeviceManager Protocol

    func startMonitoring() {
        setupBLEMonitoring()

        // 立即获取一次蓝牙设备信息
        Task {
            await refreshDevices()
        }

        // 设置定时器定期更新
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshDevices()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        centralManager?.stopScan()
        deviceCache.removeAllObjects()
        withLockedState {
            lastBLEScanDate = nil
            discoveredPeripherals.removeAll()
            batteryByBLEName.removeAll()
            bleCandidateNames.removeAll()
        }
    }

    func refreshDevices() async {
        guard beginRefreshCycle() else { return }
        defer {
            if finishRefreshCycle() {
                Task { [weak self] in
                    await self?.refreshDevices()
                }
            }
        }

        do {
            let bluetoothDevices = try getBluetoothDevices()
            withLockedState {
                _devices = bluetoothDevices
            }
            devicesSubject.send(bluetoothDevices)
        } catch {
            // Log error and keep previous device list
            debugLog("获取蓝牙设备信息失败: \(error.localizedDescription)")
        }
    }

    func getDevice(by id: UUID) -> Device? {
        withLockedState {
            _devices.first { $0.id == id }
        }
    }

    // MARK: - Private Methods

    private func setupCache() {
        deviceCache.countLimit = 50 // 最多缓存50个设备
    }

    private func setupBLEMonitoring() {
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: nil)
            debugLog("[BluetoothDeviceService][ble] initializing CBCentralManager...")
        } else {
            debugLog("[BluetoothDeviceService][ble] CBCentralManager created, waiting for state update...")
            debugLog("[BluetoothDeviceService][ble] initial state=\(centralManager?.state.rawValue ?? -1)")
            startBLEScanIfNeeded()
        }
    }

    @objc private func handleDeviceTypeOverrideChanged() {
        Task { await refreshDevices() }
    }

    private func startBLEScanIfNeeded(force: Bool = false) {
        guard let centralManager else { return }
        guard centralManager.state == .poweredOn else { return }

        let shouldSkip = withLockedState { () -> Bool in
            // 检查是否有需要补全电量的候选设备
            if !force && bleCandidateNames.isEmpty {
                return true
            }

            // 节流：距离上次扫描未超过配置的间隔，跳过（除非 force）
            if !force, let lastScan = lastBLEScanDate, Date().timeIntervalSince(lastScan) < bleScanInterval {
                return true
            }
            lastBLEScanDate = Date()
            return false
        }
        if shouldSkip {
            return
        }

        let candidateCount = withLockedState { bleCandidateNames.count }
        debugLog("[BluetoothDeviceService][ble] 开始扫描（候选设备数: \(candidateCount)）")

        centralManager.scanForPeripherals(
            withServices: [bleBatteryServiceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        let connected = centralManager.retrieveConnectedPeripherals(withServices: [bleBatteryServiceUUID])
        for peripheral in connected {
            withLockedState {
                discoveredPeripherals[peripheral.identifier] = peripheral
            }
            peripheral.delegate = self
            if peripheral.state == .connected {
                peripheral.discoverServices(nil)
            } else {
                centralManager.connect(peripheral, options: nil)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.centralManager?.stopScan()
        }
    }

    /// 获取所有已连接的蓝牙设备信息
    private func getBluetoothDevices() throws -> [Device] {
        var mergedDevices: [Device] = []
        var seenIDs = Set<UUID>()
        startBLEScanIfNeeded()
        let classHintsByName = getConnectedBluetoothClassHints()
        let typeOverridesByName = DeviceTypeOverrideStore.shared.allOverrides()

        // 读取 IORegistry 中的蓝牙外设电量（不依赖输入监控权限）
        let registryAccessories = getBluetoothAccessoriesFromIORegistry()
        let batteryByNormalizedName = Dictionary(
            registryAccessories.map { ($0.normalizedName, $0.batteryLevel) },
            uniquingKeysWith: { first, _ in first }
        )
        let batteryByBLENameSnapshot = withLockedState { batteryByBLEName }
        let mergedBatteryByName = batteryByNormalizedName.merging(batteryByBLENameSnapshot) { first, _ in first }

        for accessory in registryAccessories {
            let id = getStableHIDDeviceID(uniqueKey: "Registry_\(accessory.uniqueKey)")
            let device = Device(
                id: id,
                name: accessory.name,
                type: accessory.type,
                batteryLevel: accessory.batteryLevel,
                isCharging: false,
                lastUpdated: Date(),
                externalIdentifier: accessory.uniqueKey,
                parentExternalIdentifier: accessory.parentUniqueKey
            )
            mergedDevices.append(device)
            seenIDs.insert(id)
        }

        // 使用 HID 枚举补全设备可见性（不调用 open，避免输入监控权限依赖）
        let hidResult = getBluetoothHIDDevices(
            batteryByNormalizedName: mergedBatteryByName,
            classHintsByName: classHintsByName,
            typeOverridesByName: typeOverridesByName
        )
        withLockedState {
            bleCandidateNames = hidResult.bleCandidateNames
        }
        for device in hidResult.devices {
            if !seenIDs.contains(device.id) {
                mergedDevices.append(device)
                seenIDs.insert(device.id)
            }
        }

        // 保留原有 IOBluetooth 兜底（例如部分经典蓝牙耳机）
        if let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] {
            for btDevice in pairedDevices where btDevice.isConnected() {
                // 过滤无效设备，避免 IOBluetooth 输出 "No name or address" 噪音
                guard btDevice.addressString != nil, btDevice.name != nil else { continue }
                do {
                    let normalizedName = normalizeDeviceName(btDevice.name ?? String(localized: "device.unknown_name"))
                    let batteryOverride = mergedBatteryByName[normalizedName]
                    let device = try createDevice(
                        from: btDevice,
                        batteryOverride: batteryOverride,
                        typeOverridesByNormalizedName: typeOverridesByName
                    )
                    if !seenIDs.contains(device.id) {
                        mergedDevices.append(device)
                        seenIDs.insert(device.id)
                    }
                } catch {
                    // 记录错误但继续处理其他设备
                    debugLog("处理蓝牙设备失败: \(error.localizedDescription)")
                }
            }
        }

        let dedupedDevices = dedupeDevices(
            mergedDevices,
            classHintsByNormalizedName: classHintsByName,
            typeOverridesByNormalizedName: typeOverridesByName
        )

        let summary = dedupedDevices.map { "\($0.name):\($0.batteryLevel)" }.joined(separator: ", ")
        debugLog("[BluetoothDeviceService] registry=\(registryAccessories.count) ble=\(batteryByBLENameSnapshot.count) hid=\(hidResult.devices.count) merged=\(mergedDevices.count) deduped=\(dedupedDevices.count) [\(summary)]")

        return dedupedDevices
    }

    private func dedupeDevices(
        _ devices: [Device],
        classHintsByNormalizedName: [String: DeviceType],
        typeOverridesByNormalizedName: [String: DeviceType]
    ) -> [Device] {
        var bestByName: [String: Device] = [:]
        for device in devices {
            let key = normalizeDeviceName(device.name)
            guard !key.isEmpty else { continue }

            if let existing = bestByName[key] {
                if shouldReplace(
                    existing: existing,
                    with: device,
                    classHintsByNormalizedName: classHintsByNormalizedName,
                    typeOverridesByNormalizedName: typeOverridesByNormalizedName
                ) {
                    bestByName[key] = device
                }
            } else {
                bestByName[key] = device
            }
        }
        return Array(bestByName.values)
    }

    private func publishBLEBatteryUpdateIfNeeded() {
        let updatedDevices: [Device]? = withLockedState {
            guard !_devices.isEmpty else { return nil }

            var changed = false
            let now = Date()
            let updated = _devices.map { device -> Device in
                let normalizedName = normalizeDeviceName(device.name)
                guard let level = batteryByBLEName[normalizedName], level != device.batteryLevel else {
                    return device
                }
                changed = true
                return Device(
                    id: device.id,
                    name: device.name,
                    type: device.type,
                    batteryLevel: level,
                    isCharging: device.isCharging,
                    lastUpdated: now
                )
            }

            guard changed else { return nil }
            _devices = updated
            return updated
        }

        guard let updatedDevices else { return }
        devicesSubject.send(updatedDevices)
    }

    private func shouldReplace(
        existing: Device,
        with candidate: Device,
        classHintsByNormalizedName: [String: DeviceType],
        typeOverridesByNormalizedName: [String: DeviceType]
    ) -> Bool {
        let existingKnown = existing.batteryLevel >= 0
        let candidateKnown = candidate.batteryLevel >= 0
        if existingKnown != candidateKnown {
            return candidateKnown
        }

        if existingKnown && candidateKnown && candidate.batteryLevel > existing.batteryLevel {
            return true
        }

        let hasKeyboardMouseConflict =
            (existing.type == .bluetoothKeyboard && candidate.type == .bluetoothMouse)
            || (existing.type == .bluetoothMouse && candidate.type == .bluetoothKeyboard)
        if hasKeyboardMouseConflict {
            let normalizedName = normalizeDeviceName(existing.name)
            if let overrideType = typeOverridesByNormalizedName[normalizedName],
               overrideType == .bluetoothKeyboard || overrideType == .bluetoothMouse {
                return candidate.type == overrideType
            }
            if let classHint = classHintsByNormalizedName[normalizedName],
               classHint == .bluetoothKeyboard || classHint == .bluetoothMouse {
                return candidate.type == classHint
            }
            return deviceTypePriority(candidate.type) > deviceTypePriority(existing.type)
        }

        // 相同名称冲突时，优先保留输入设备类型，避免 IOBluetooth 兜底误分类成耳机。
        return deviceTypePriority(candidate.type) > deviceTypePriority(existing.type)
    }

    private func deviceTypePriority(_ type: DeviceType) -> Int {
        switch type {
        case .bluetoothKeyboard:
            return 4
        case .bluetoothMouse:
            return 3
        case .bluetoothHeadphone, .airPods, .airPodsLeft, .airPodsRight, .airPodsCase:
            return 2
        case .bluetoothDevice:
            return 1
        case .mac, .iPhone, .iPad, .appleWatch:
            return 0
        }
    }

    private func getBluetoothHIDDevices(
        batteryByNormalizedName: [String: Int],
        classHintsByName: [String: DeviceType],
        typeOverridesByName: [String: DeviceType]
    ) -> (devices: [Device], bleCandidateNames: Set<String>) {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard CFGetTypeID(manager) == IOHIDManagerGetTypeID() else {
            return (devices: [], bleCandidateNames: Set<String>())
        }

        let matchers: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: 0x01,
                kIOHIDDeviceUsageKey as String: 0x06
            ],
            [
                kIOHIDDeviceUsagePageKey as String: 0x01,
                kIOHIDDeviceUsageKey as String: 0x02
            ],
            [
                kIOHIDDeviceUsagePageKey as String: 0x01,
                kIOHIDDeviceUsageKey as String: 0x01
            ],
            [
                kIOHIDDeviceUsagePageKey as String: 0x0C,
                kIOHIDDeviceUsageKey as String: 0x01
            ]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager, matchers as CFArray)

        guard let deviceSet = IOHIDManagerCopyDevices(manager) else {
            return (devices: [], bleCandidateNames: Set<String>())
        }
        let hidDevices = (deviceSet as NSSet).compactMap { device -> IOHIDDevice? in
            let cfDevice = device as CFTypeRef
            guard CFGetTypeID(cfDevice) == IOHIDDeviceGetTypeID() else { return nil }
            return unsafeBitCast(cfDevice, to: IOHIDDevice.self)
        }
        if hidDevices.isEmpty {
            return (devices: [], bleCandidateNames: Set<String>())
        }

        var devices: [Device] = []
        var candidateNames = Set<String>()
        for hidDevice in hidDevices {
            let transport = hidPropertyString(hidDevice, key: kIOHIDTransportKey as String)?.lowercased() ?? ""
            guard transport.contains("bluetooth") else { continue }

            let name = hidPropertyString(hidDevice, key: kIOHIDProductKey as String)
                ?? hidPropertyString(hidDevice, key: "Product")
                ?? String(localized: "device.bluetooth_device_fallback")
            let normalizedName = normalizeDeviceName(name)
            let usagePage = hidPropertyInt(hidDevice, key: kIOHIDPrimaryUsagePageKey as String) ?? -1
            let usage = hidPropertyInt(hidDevice, key: kIOHIDPrimaryUsageKey as String) ?? -1
            let usagePairs = hidUsagePairs(hidDevice)
            let classHint = classHintsByName[normalizedName]
            let typeDecision = determineDeviceTypeWithSource(
                fromName: name,
                usagePage: usagePage,
                usage: usage,
                usagePairs: usagePairs,
                classHint: classHint
            )
            let overrideType = typeOverridesByName[normalizedName]
            let type = overrideType ?? typeDecision.type
            let usagePairsText = usagePairs.map { "\($0.usagePage):\($0.usage)" }.joined(separator: ",")
            let source = overrideType == nil ? typeDecision.source : "user_override"
            debugLog("[BluetoothDeviceService][type] name=\(name) type=\(type.rawValue) source=\(source) classHint=\(classHint?.rawValue ?? "none") override=\(overrideType?.rawValue ?? "none") primary=\(usagePage):\(usage) usagePairs=[\(usagePairsText)]")
            let uniqueKey = hidPropertyString(hidDevice, key: kIOHIDSerialNumberKey as String)
                ?? hidPropertyString(hidDevice, key: kIOHIDPhysicalDeviceUniqueIDKey as String)
                ?? normalizedName
            let usageKey = "\(usagePage)_\(usage)"
            let id = getStableHIDDeviceID(uniqueKey: "HID_\(uniqueKey)_\(usageKey)")
            let battery = batteryByNormalizedName[normalizedName]
                ?? hidBatteryLevel(for: hidDevice)
                ?? hidRegistryBatteryLevel(for: hidDevice)
                ?? -1

            if battery < 0 {
                candidateNames.insert(normalizedName)
            }

            #if DEBUG
            if battery < 0 {
                debugLogMissingBattery(
                    for: hidDevice,
                    uniqueKey: uniqueKey,
                    name: name,
                    transport: transport
                )
            }
            #endif

            let device = Device(
                id: id,
                name: name,
                type: type,
                batteryLevel: battery,
                isCharging: false,
                lastUpdated: Date()
            )
            devices.append(device)
        }

        // 同一设备通常会暴露多个 HID 接口，仅保留每个“名称 + 类型”的最佳记录
        var bestByFingerprint: [String: Device] = [:]
        for device in devices {
            let fingerprint = "\(normalizeDeviceName(device.name))|\(device.type.rawValue)"
            if let existing = bestByFingerprint[fingerprint] {
                if existing.batteryLevel < 0, device.batteryLevel >= 0 {
                    bestByFingerprint[fingerprint] = device
                }
            } else {
                bestByFingerprint[fingerprint] = device
            }
        }

        return (Array(bestByFingerprint.values), candidateNames)
    }

    /// 从 IORegistry 读取蓝牙外设（优先 Apple 外设）
    private func getBluetoothAccessoriesFromIORegistry() -> [RegistryAccessory] {
        let classNames = [
            "AppleDeviceManagementHIDEventService",
            "AppleBluetoothHIDKeyboard",
            "AppleBluetoothHIDMouse"
        ]

        var accessories: [RegistryAccessory] = getBluetoothAccessoriesFromSystemProfiler()
        for className in classNames {
            accessories.append(contentsOf: collectRegistryAccessories(for: className))
        }

        // 去重（优先保留有电量值的记录）
        var bestByKey: [String: RegistryAccessory] = [:]
        for accessory in accessories {
            if let existing = bestByKey[accessory.uniqueKey] {
                if existing.batteryLevel < 0 && accessory.batteryLevel >= 0 {
                    bestByKey[accessory.uniqueKey] = accessory
                }
            } else {
                bestByKey[accessory.uniqueKey] = accessory
            }
        }
        return Array(bestByKey.values)
    }

    private func getBluetoothAccessoriesFromSystemProfiler() -> [RegistryAccessory] {
        guard let output = runSystemProfilerBluetooth() else { return [] }
        return BluetoothSystemProfilerParser.parse(output).map {
            RegistryAccessory(
                uniqueKey: $0.uniqueKey,
                name: $0.name,
                normalizedName: $0.normalizedName,
                batteryLevel: $0.batteryLevel,
                type: $0.type,
                parentUniqueKey: $0.parentUniqueKey
            )
        }
    }

    private func runSystemProfilerBluetooth(timeout: TimeInterval = 20) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-detailLevel", "mini"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            debugLog("system_profiler 启动失败: \(error.localizedDescription)")
            return nil
        }

        let group = DispatchGroup()
        group.enter()
        var stdout = Data()
        DispatchQueue.global(qos: .utility).async {
            stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        group.enter()
        var stderr = Data()
        DispatchQueue.global(qos: .utility).async {
            stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        let waitResult = group.wait(timeout: .now() + timeout)
        if waitResult == .timedOut {
            process.terminate()
            debugLog("system_profiler 超时")
            return nil
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrText = String(decoding: stderr, as: UTF8.self)
            debugLog("system_profiler 退出失败: \(stderrText)")
            return nil
        }

        return String(decoding: stdout, as: UTF8.self)
    }

    private func parseSystemProfilerBluetoothOutput(_ output: String) -> [RegistryAccessory] {
        let lines = output.components(separatedBy: .newlines)
        var accessories: [RegistryAccessory] = []
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
                        RegistryAccessory(
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
                        RegistryAccessory(
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
                        RegistryAccessory(
                            uniqueKey: "\(uniqueKey)::case",
                            name: "\(currentName) · \(String(localized: "device.type.airpods_case"))",
                            normalizedName: normalizedName,
                            batteryLevel: chargingCase,
                            type: .airPodsCase,
                            parentUniqueKey: uniqueKey
                        )
                    )
                }
            } else if let overall, overall >= 0 || isHeadphoneLike {
                accessories.append(
                    RegistryAccessory(
                        uniqueKey: uniqueKey,
                        name: currentName,
                        normalizedName: normalizedName,
                        batteryLevel: overall,
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

            guard currentName != nil, indent > currentIndent else { continue }
            guard let separatorRange = trimmed.range(of: ":") else { continue }
            let key = String(trimmed[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            currentFields[key] = value
        }

        flushCurrent()
        return accessories
    }

    private func parsePercent(_ value: String?) -> Int? {
        guard let value else { return nil }
        let digits = value.filter { $0.isNumber }
        guard let level = Int(digits) else { return nil }
        return max(-1, min(100, level))
    }

    private func collectRegistryAccessories(for className: String) -> [RegistryAccessory] {
        guard let matching = IOServiceMatching(className) else { return [] }

        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }

        var accessories: [RegistryAccessory] = []
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry) }

            let name = registryString(entry, key: "Product")
                ?? registryString(entry, key: "ProductName")
                ?? registryString(entry, key: "DeviceName")
                ?? registryString(entry, key: "Name")
                ?? String(localized: "device.bluetooth_device_fallback")
            let normalizedName = normalizeDeviceName(name)
            let type = determineDeviceType(fromName: name)
            let uniqueKey = registryString(entry, key: "SerialNumber")
                ?? registryString(entry, key: "DeviceAddress")
                ?? normalizedName
            let isBuiltIn = registryBool(entry, key: "Built-In")

            let properties = registryProperties(entry)
            let componentLevels = extractBatteryComponentLevels(from: properties)

            if !isBuiltIn {
                if type == .airPods, componentLevels.hasSplitValues {
                    if let left = componentLevels.left {
                        accessories.append(
                            RegistryAccessory(
                                uniqueKey: "\(uniqueKey)::left",
                                name: "\(name) · \(String(localized: "device.type.airpods_left"))",
                                normalizedName: normalizedName,
                                batteryLevel: left,
                                type: .airPodsLeft,
                                parentUniqueKey: uniqueKey
                            )
                        )
                    }
                    if let right = componentLevels.right {
                        accessories.append(
                            RegistryAccessory(
                                uniqueKey: "\(uniqueKey)::right",
                                name: "\(name) · \(String(localized: "device.type.airpods_right"))",
                                normalizedName: normalizedName,
                                batteryLevel: right,
                                type: .airPodsRight,
                                parentUniqueKey: uniqueKey
                            )
                        )
                    }
                    if let chargingCase = componentLevels.caseLevel {
                        accessories.append(
                            RegistryAccessory(
                                uniqueKey: "\(uniqueKey)::case",
                                name: "\(name) · \(String(localized: "device.type.airpods_case"))",
                                normalizedName: normalizedName,
                                batteryLevel: chargingCase,
                                type: .airPodsCase,
                                parentUniqueKey: uniqueKey
                            )
                        )
                    }
                } else {
                    let battery = componentLevels.overall
                        ?? registryInt(entry, key: "BatteryPercent")
                        ?? registryInt(entry, key: "BatteryPercentSingle")
                        ?? registryInt(entry, key: "BatteryLevel")
                        ?? registryInt(entry, key: "Battery")
                        ?? -1

                    accessories.append(
                        RegistryAccessory(
                            uniqueKey: uniqueKey,
                            name: name,
                            normalizedName: normalizedName,
                            batteryLevel: max(-1, min(100, battery)),
                            type: type,
                            parentUniqueKey: nil
                        )
                    )
                }
            }

            entry = IOIteratorNext(iterator)
        }

        return accessories
    }

    private func registryString(_ entry: io_registry_entry_t, key: String) -> String? {
        guard let value = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        return value as? String
    }

    private func registryInt(_ entry: io_registry_entry_t, key: String) -> Int? {
        guard let value = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return nil
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
    }

    private func registryBool(_ entry: io_registry_entry_t, key: String) -> Bool {
        guard let value = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() else {
            return false
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return false
    }

    private func registryProperties(_ entry: io_registry_entry_t) -> [String: Any] {
        var unmanagedProps: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedProps, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let props = unmanagedProps?.takeRetainedValue() as? [String: Any] else {
            return [:]
        }
        return props
    }

    private func extractBatteryComponentLevels(from dict: [String: Any]) -> BatteryComponentLevels {
        BatteryComponentLevels(
            overall: extractBatteryLevel(from: dict, keys: [
                "BatteryPercent",
                "BatteryPercentSingle",
                "BatteryLevel",
                "Battery",
                "DeviceBatteryLevel",
                "batteryLevel",
                "battery_percent"
            ]),
            left: extractBatteryLevel(from: dict, keys: [
                "BatteryPercentLeft",
                "LeftBatteryPercent",
                "LeftBatteryLevel",
                "BatteryLeft",
                "BatteryLevelLeft"
            ]),
            right: extractBatteryLevel(from: dict, keys: [
                "BatteryPercentRight",
                "RightBatteryPercent",
                "RightBatteryLevel",
                "BatteryRight",
                "BatteryLevelRight"
            ]),
            caseLevel: extractBatteryLevel(from: dict, keys: [
                "BatteryPercentCase",
                "CaseBatteryPercent",
                "CaseBatteryLevel",
                "BatteryCase",
                "BatteryLevelCase"
            ])
        )
    }

    private func extractBatteryLevel(from dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if let value = dict[key], let level = intValue(from: value) {
                return level
            }
        }

        for value in dict.values {
            if let subDict = value as? [String: Any], let nested = extractBatteryLevel(from: subDict, keys: keys) {
                return nested
            }
        }
        return nil
    }

    private func normalizeDeviceName(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }

    private func getConnectedBluetoothClassHints() -> [String: DeviceType] {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return [:]
        }

        var hints: [String: DeviceType] = [:]
        for btDevice in pairedDevices where btDevice.isConnected() {
            guard let name = btDevice.name, !name.isEmpty else { continue }
            let normalizedName = normalizeDeviceName(name)
            guard !normalizedName.isEmpty else { continue }

            let type = determineDeviceType(from: btDevice)
            if type == .bluetoothKeyboard || type == .bluetoothMouse {
                hints[normalizedName] = type
            }
        }
        return hints
    }

    private func hidPropertyString(_ device: IOHIDDevice, key: String) -> String? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
        return value as? String
    }

    private func hidPropertyInt(_ device: IOHIDDevice, key: String) -> Int? {
        guard let value = IOHIDDeviceGetProperty(device, key as CFString) else { return nil }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String, let intValue = Int(text) {
            return intValue
        }
        return nil
    }

    private func hidBatteryLevel(for device: IOHIDDevice) -> Int? {
        let candidates = [
            "BatteryPercent",
            "BatteryPercentSingle",
            "BatteryLevel",
            "Battery",
            "DeviceBatteryLevel",
            "batteryLevel",
            "battery_percent"
        ]
        for key in candidates {
            if let level = hidPropertyInt(device, key: key) {
                return max(-1, min(100, level))
            }
        }
        return nil
    }

    private func hidUsagePairs(_ device: IOHIDDevice) -> [(usagePage: Int, usage: Int)] {
        guard let raw = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) else {
            return []
        }
        guard let pairs = raw as? [[String: Any]] else { return [] }

        var result: [(usagePage: Int, usage: Int)] = []
        for pair in pairs {
            let usagePageRaw = pair[kIOHIDDeviceUsagePageKey as String]
                ?? pair["UsagePage"]
                ?? pair["DeviceUsagePage"]
            let usageRaw = pair[kIOHIDDeviceUsageKey as String]
                ?? pair["Usage"]
                ?? pair["DeviceUsage"]
            guard let usagePageRaw,
                  let usageRaw,
                  let usagePage = intValue(from: usagePageRaw),
                  let usage = intValue(from: usageRaw) else {
                continue
            }
            result.append((usagePage: usagePage, usage: usage))
        }
        return result
    }

    private func hidRegistryBatteryLevel(for device: IOHIDDevice) -> Int? {
        let service = IOHIDDeviceGetService(device)
        guard service != 0 else { return nil }

        if let level = registryBatteryLevel(service) {
            return level
        }

        var current = service
        var depth = 0
        var retainedParents: [io_object_t] = []
        defer {
            for object in retainedParents {
                IOObjectRelease(object)
            }
        }

        while depth < 5 {
            var parent: io_registry_entry_t = 0
            let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            guard kr == KERN_SUCCESS, parent != 0 else { break }
            retainedParents.append(parent)

            if let level = registryBatteryLevel(parent) {
                return level
            }

            current = parent
            depth += 1
        }
        return nil
    }

    #if DEBUG
    private func debugLogMissingBattery(
        for hidDevice: IOHIDDevice,
        uniqueKey: String,
        name: String,
        transport: String
    ) {
        guard !debugLoggedUnknownBatteryDevices.contains(uniqueKey) else { return }
        debugLoggedUnknownBatteryDevices.insert(uniqueKey)

        let vendorID = hidPropertyInt(hidDevice, key: kIOHIDVendorIDKey as String) ?? -1
        let productID = hidPropertyInt(hidDevice, key: kIOHIDProductIDKey as String) ?? -1
        let primaryUsagePage = hidPropertyInt(hidDevice, key: kIOHIDPrimaryUsagePageKey as String) ?? -1
        let primaryUsage = hidPropertyInt(hidDevice, key: kIOHIDPrimaryUsageKey as String) ?? -1

        debugLog("[BluetoothDeviceService][debug] unknown battery device name=\(name) key=\(uniqueKey) transport=\(transport) vid=\(vendorID) pid=\(productID) usagePage=\(primaryUsagePage) usage=\(primaryUsage)")

        let directKeys = [
            "BatteryPercent",
            "BatteryPercentSingle",
            "BatteryLevel",
            "Battery",
            "DeviceBatteryLevel",
            "batteryLevel",
            "battery_percent"
        ]
        var directValues: [String] = []
        for key in directKeys {
            if let value = IOHIDDeviceGetProperty(hidDevice, key as CFString) {
                directValues.append("\(key)=\(value)")
            }
        }
        if directValues.isEmpty {
            debugLog("[BluetoothDeviceService][debug] direct HID battery keys: <none>")
        } else {
            debugLog("[BluetoothDeviceService][debug] direct HID battery keys: \(directValues.joined(separator: ", "))")
        }

        let service = IOHIDDeviceGetService(hidDevice)
        if service != 0 {
            debugLogRegistryBatteryKeys(for: service, tag: "service")

            var current = service
            var depth = 0
            var retainedParents: [io_object_t] = []
            defer {
                for object in retainedParents {
                    IOObjectRelease(object)
                }
            }

            while depth < 5 {
                var parent: io_registry_entry_t = 0
                let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
                guard kr == KERN_SUCCESS, parent != 0 else { break }
                retainedParents.append(parent)
                debugLogRegistryBatteryKeys(for: parent, tag: "parent_\(depth)")
                current = parent
                depth += 1
            }
        }
    }

    private func debugLogRegistryBatteryKeys(for entry: io_registry_entry_t, tag: String) {
        var unmanagedProps: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedProps, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let props = unmanagedProps?.takeRetainedValue() as? [String: Any] else {
            debugLog("[BluetoothDeviceService][debug] \(tag): <no properties>")
            return
        }

        let interestingKeys = props.keys.filter {
            let key = $0.lowercased()
            return key.contains("battery") || key.contains("power") || key.contains("percent") || key.contains("level") || key.contains("charge")
        }.sorted()

        if interestingKeys.isEmpty {
            debugLog("[BluetoothDeviceService][debug] \(tag): no battery-like keys")
            return
        }

        let mapped = interestingKeys.map { key in
            "\(key)=\(String(describing: props[key]!))"
        }
        debugLog("[BluetoothDeviceService][debug] \(tag): \(mapped.joined(separator: ", "))")
    }
    #endif

    private func registryBatteryLevel(_ entry: io_registry_entry_t) -> Int? {
        var unmanagedProps: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(entry, &unmanagedProps, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let props = unmanagedProps?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        if let direct = extractBatteryLevel(from: props) {
            return max(-1, min(100, direct))
        }

        let batteryKeys = props.keys.filter { $0.lowercased().contains("battery") }
        if !batteryKeys.isEmpty {
            debugLog("[BluetoothDeviceService] battery-like keys: \(batteryKeys)")
        }

        return nil
    }

    private func extractBatteryLevel(from dict: [String: Any]) -> Int? {
        let keys = [
            "BatteryPercent",
            "BatteryPercentSingle",
            "BatteryLevel",
            "Battery",
            "DeviceBatteryLevel",
            "batteryLevel",
            "battery_percent"
        ]
        for key in keys {
            if let value = dict[key] {
                if let level = intValue(from: value) {
                    return level
                }
            }
        }

        for value in dict.values {
            if let subDict = value as? [String: Any], let nested = extractBatteryLevel(from: subDict) {
                return nested
            }
        }
        return nil
    }

    private func intValue(from any: Any) -> Int? {
        if let number = any as? NSNumber {
            return number.intValue
        }
        if let text = any as? String, let value = Int(text) {
            return value
        }
        return nil
    }

    private func stringValue(from data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters)),
           !text.isEmpty {
            return text
        }
        return nil
    }

    private func determineDeviceType(
        fromName name: String,
        usagePage: Int? = nil,
        usage: Int? = nil,
        usagePairs: [(usagePage: Int, usage: Int)] = [],
        classHint: DeviceType? = nil
    ) -> DeviceType {
        determineDeviceTypeWithSource(
            fromName: name,
            usagePage: usagePage,
            usage: usage,
            usagePairs: usagePairs,
            classHint: classHint
        ).type
    }

    private func determineDeviceTypeWithSource(
        fromName name: String,
        usagePage: Int? = nil,
        usage: Int? = nil,
        usagePairs: [(usagePage: Int, usage: Int)] = [],
        classHint: DeviceType? = nil
    ) -> (type: DeviceType, source: String) {
        let normalizedName = normalizeDeviceName(name)

        if normalizedName.contains("airpods") {
            return (.airPods, "name_airpods")
        }
        if normalizedName.contains("beats") || normalizedName.contains("buds") {
            return (.bluetoothHeadphone, "name_headphone")
        }

        // 优先级 1：HID UsagePairs（协议级）
        if !usagePairs.isEmpty {
            let hasMouse = usagePairs.contains { pair in
                pair.usagePage == 0x01 && (pair.usage == 0x02 || pair.usage == 0x01)
            }
            let hasKeyboard = usagePairs.contains { pair in
                (pair.usagePage == 0x01 && pair.usage == 0x06) || pair.usagePage == 0x07
            }

            if hasMouse && !hasKeyboard {
                return (.bluetoothMouse, "hid_usage_pairs")
            }
            if hasKeyboard && !hasMouse {
                return (.bluetoothKeyboard, "hid_usage_pairs")
            }
            if hasMouse && hasKeyboard {
                // 键鼠冲突时，优先使用 IOBluetooth 的 Class-of-Device 提示（动态，不写死）。
                if let classHint,
                   classHint == .bluetoothKeyboard || classHint == .bluetoothMouse {
                    return (classHint, "iobluetooth_cod_hint")
                }
                return (.bluetoothDevice, "hid_usage_pairs_conflict_generic")
            }
        }

        if let usagePage, let usage {
            if usagePage == 0x01 {
                if usage == 0x06 {
                    return (.bluetoothKeyboard, "hid_primary_usage")
                }
                if usage == 0x02 || usage == 0x01 {
                    return (.bluetoothMouse, "hid_primary_usage")
                }
            }
            if usagePage == 0x07 {
                return (.bluetoothKeyboard, "hid_primary_usage")
            }
            if usagePage == 0x0B {
                return (.bluetoothHeadphone, "hid_primary_usage")
            }
            if usagePage == 0x01 || usagePage == 0x07 || usagePage == 0x0C {
                return (.bluetoothDevice, "hid_input_generic")
            }
        }

        return (.bluetoothDevice, "default_generic")
    }

    private func getStableHIDDeviceID(uniqueKey: String) -> UUID {
        let key = "HIDBluetoothDevice_\(uniqueKey)"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }

    /// 从蓝牙设备创建 Device 对象
    private func createDevice(
        from btDevice: IOBluetoothDevice,
        batteryOverride: Int?,
        typeOverridesByNormalizedName: [String: DeviceType]
    ) throws -> Device {
        // 获取设备地址作为缓存键
        guard let address = btDevice.addressString else {
            throw NSError(domain: "BluetoothDeviceService", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.device_address_unavailable")])
        }

        // 获取设备名称
        let deviceName = btDevice.name ?? String(localized: "device.unknown_name")

        // 尝试获取电池电量
        let batteryLevel = batteryOverride ?? getBatteryLevel(for: btDevice)

        // 判断设备类型（使用缓存优化）
        let deviceType = getCachedDeviceType(for: btDevice, address: address)
        let normalizedName = normalizeDeviceName(deviceName)
        let finalType = typeOverridesByNormalizedName[normalizedName] ?? deviceType

        // 生成设备 ID
        let deviceID = getDeviceID(for: btDevice, address: address)

        let device = Device(
            id: deviceID,
            name: deviceName,
            type: finalType,
            batteryLevel: batteryLevel,
            isCharging: false, // 蓝牙设备通常无法检测充电状态
            lastUpdated: Date()
        )

        // 缓存设备信息
        cacheDevice(device, address: address)

        return device
    }

    /// 获取蓝牙设备的电池电量
    /// 返回 -1 表示电量未知
    private func getBatteryLevel(for device: IOBluetoothDevice) -> Int {
        // 尝试通过 HID 服务获取电池电量
        // 这是一个简化的实现，实际可能需要更复杂的 HID 报告解析

        // Method 1: Try to get battery level from device services
        if let services = device.services as? [IOBluetoothSDPServiceRecord] {
            for service in services {
                // Check for Battery Service (UUID 0x180F)
                // This is device-specific and may not work for all devices
                if let serviceName = service.getServiceName(),
                   serviceName.lowercased().contains("battery") {
                    // Battery service found, but we need GATT to read the actual value
                    // This requires more complex implementation
                }
            }
        }

        // Method 2: For Apple devices (Magic Keyboard, Magic Mouse, etc.)
        // These often report battery through system APIs
        if let name = device.name?.lowercased() {
            if name.contains("magic") || name.contains("apple") {
                // Apple devices may expose battery through IOKit
                // This requires additional IOKit queries beyond IOBluetooth
                // For now, we can't reliably get this information
            }
        }

        // Return -1 to indicate battery level is unknown
        // Don't return 100 as it's misleading
        return -1
    }

    /// 获取缓存的设备类型
    private func getCachedDeviceType(for device: IOBluetoothDevice, address: String) -> DeviceType {
        let cacheKey = "type_\(address)" as NSString

        if let cached = deviceCache.object(forKey: cacheKey) {
            return cached.type
        }

        let type = determineDeviceType(from: device)
        return type
    }

    /// 根据蓝牙设备特征判断设备类型
    private func determineDeviceType(from device: IOBluetoothDevice) -> DeviceType {
        // 根据设备类别判断
        let deviceClass = device.classOfDevice
        let majorDeviceClass = (deviceClass >> 8) & 0x1F

        switch majorDeviceClass {
        case 0x05: // Peripheral (keyboard, mouse, etc.)
            let minorDeviceClass = (deviceClass >> 2) & 0x3F
            if minorDeviceClass & 0x10 != 0 { // Keyboard
                return .bluetoothKeyboard
            } else if minorDeviceClass & 0x20 != 0 { // Pointing device
                return .bluetoothMouse
            }
        case 0x04: // Audio/Video
            return .bluetoothHeadphone
        default:
            break
        }

        return .bluetoothDevice
    }

    /// 获取蓝牙设备的唯一标识符
    private func getDeviceID(for device: IOBluetoothDevice, address: String) -> UUID {
        let key = "BluetoothDevice_\(address)"

        // 尝试从 UserDefaults 获取已保存的 UUID
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        // 如果没有保存过，创建新的 UUID 并保存
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }

    /// 缓存设备信息
    private func cacheDevice(_ device: Device, address: String) {
        let cached = CachedDevice(device: device, type: device.type)
        let cacheKey = "type_\(address)" as NSString
        deviceCache.setObject(cached, forKey: cacheKey)
    }
}

// MARK: - Supporting Types

/// 缓存的设备信息
private class CachedDevice {
    let device: Device
    let type: DeviceType

    init(device: Device, type: DeviceType) {
        self.device = device
        self.type = type
    }
}

private struct RegistryAccessory {
    let uniqueKey: String
    let name: String
    let normalizedName: String
    let batteryLevel: Int
    let type: DeviceType
    let parentUniqueKey: String?
}

private struct BatteryComponentLevels {
    let overall: Int?
    let left: Int?
    let right: Int?
    let caseLevel: Int?

    var hasSplitValues: Bool {
        left != nil || right != nil || caseLevel != nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothDeviceService: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let auth: String
        if #available(macOS 10.15, *) {
            switch CBManager.authorization {
            case .allowedAlways:
                auth = "allowedAlways"
            case .denied:
                auth = "denied"
            case .restricted:
                auth = "restricted"
            case .notDetermined:
                auth = "notDetermined"
            @unknown default:
                auth = "unknown"
            }
        } else {
            auth = "legacy"
        }
        debugLog("[BluetoothDeviceService][ble] state=\(central.state.rawValue) auth=\(auth)")

        switch central.state {
        case .unknown:
            debugLog("[BluetoothDeviceService][ble] state=unknown (0)")
        case .resetting:
            debugLog("[BluetoothDeviceService][ble] state=resetting (1)")
        case .unsupported:
            debugLog("[BluetoothDeviceService][ble] state=unsupported (2) - Bluetooth not supported on this device")
        case .unauthorized:
            debugLog("[BluetoothDeviceService][ble] state=unauthorized (3) - App not authorized to use Bluetooth")
            debugLog("[BluetoothDeviceService][ble] Check: System Settings > Privacy & Security > Bluetooth")
        case .poweredOff:
            debugLog("[BluetoothDeviceService][ble] state=poweredOff (4) - Bluetooth is turned off")
        case .poweredOn:
            debugLog("[BluetoothDeviceService][ble] state=poweredOn (5) - Ready to scan")
            startBLEScanIfNeeded(force: true)
        @unknown default:
            debugLog("[BluetoothDeviceService][ble] state=unknown default (\(central.state.rawValue))")
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = peripheral.name ?? advName ?? ""
        guard !name.isEmpty else { return }
        let normalizedName = normalizeDeviceName(name)

        withLockedState {
            discoveredPeripherals[peripheral.identifier] = peripheral
        }
        peripheral.delegate = self

        if peripheral.state == .connected {
            peripheral.discoverServices([bleBatteryServiceUUID])
            return
        }

        // 优先连接 HID 已识别但电量未知的候选设备
        let isKnownUnknownBatteryHID = withLockedState {
            bleCandidateNames.contains(normalizedName)
        }

        // 其次连接名称可识别为键盘/鼠标的设备
        let type = determineDeviceType(fromName: name)
        let isLikelyInputDevice = type == .bluetoothKeyboard || type == .bluetoothMouse
        guard isKnownUnknownBatteryHID || isLikelyInputDevice else { return }

        let reason = isKnownUnknownBatteryHID ? "hid-unknown-battery" : "likely-input-device"
        debugLog("[BluetoothDeviceService][ble] discover candidate name=\(name) id=\(peripheral.identifier) rssi=\(RSSI) reason=\(reason)")

        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        debugLog("[BluetoothDeviceService][ble] connected name=\(peripheral.name ?? "unknown")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        withLockedState {
            discoveredPeripherals.removeValue(forKey: peripheral.identifier)
        }
        debugLog("[BluetoothDeviceService][ble] connect failed name=\(peripheral.name ?? "unknown") err=\(error?.localizedDescription ?? "nil")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        withLockedState {
            discoveredPeripherals.removeValue(forKey: peripheral.identifier)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else { return }
        guard let services = peripheral.services else { return }

        let serviceList = services.map { $0.uuid.uuidString }.joined(separator: ",")
        debugLog("[BluetoothDeviceService][ble] services name=\(peripheral.name ?? "unknown") uuids=[\(serviceList)]")

        for service in services {
            if service.uuid == bleBatteryServiceUUID {
                peripheral.discoverCharacteristics([bleBatteryLevelCharUUID], for: service)
            } else {
                // 也探测非标准服务，便于识别厂商自定义电量特征
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let characteristics = service.characteristics else { return }

        let chars = characteristics.map { $0.uuid.uuidString }.joined(separator: ",")
        debugLog("[BluetoothDeviceService][ble] chars service=\(service.uuid.uuidString) name=\(peripheral.name ?? "unknown") uuids=[\(chars)]")

        for characteristic in characteristics {
            if characteristic.uuid == bleBatteryLevelCharUUID {
                peripheral.readValue(for: characteristic)
                continue
            }

            // 尝试读取可读特征，捕获厂商自定义电量字段
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil else { return }
        guard let data = characteristic.value, let firstByte = data.first else { return }

        let normalizedName = normalizeDeviceName(peripheral.name ?? "")
        let level = max(0, min(100, Int(firstByte)))
        let isStandardBattery = characteristic.uuid == bleBatteryLevelCharUUID
        let isPlausibleCustomBattery = data.count == 1 && (0...100).contains(Int(firstByte))
        if !normalizedName.isEmpty && (isStandardBattery || isPlausibleCustomBattery) {
            withLockedState {
                batteryByBLEName[normalizedName] = level
            }
            publishBLEBatteryUpdateIfNeeded()
            debugLog("[BluetoothDeviceService][ble] battery name=\(peripheral.name ?? "unknown") level=\(level) char=\(characteristic.uuid.uuidString) standard=\(isStandardBattery)")
        }

        if !isStandardBattery {
            debugLog("[BluetoothDeviceService][ble] value name=\(peripheral.name ?? "unknown") char=\(characteristic.uuid.uuidString) bytes=\(data.map { String($0) }.joined(separator: ","))")
        }

        if isStandardBattery || isPlausibleCustomBattery {
            // 读取后主动断开，降低连接占用
            centralManager?.cancelPeripheralConnection(peripheral)
        }
    }
}

extension BluetoothDeviceService {
    private func debugLog(_ message: @autoclosure () -> String) {
        AppLogger.debug(message(), category: AppLogger.bluetooth)
    }

    private func withLockedState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
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
