import Foundation
import Combine
import IOKit.ps

/// Mac 电池服务（优化版）
/// 负责监控 Mac 本机的电池状态
final class MacBatteryService: DeviceManager {
    // MARK: - Properties

    private var _devices: [Device] = []
    private let devicesSubject = CurrentValueSubject<[Device], Never>([])
    private var timer: Timer?
    private let updateInterval: TimeInterval = 60.0 // 每60秒更新一次

    private let stateLock = NSLock()

    private func withLockedState<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    var devices: [Device] {
        withLockedState { _devices }
    }

    var devicesPublisher: AnyPublisher<[Device], Never> {
        return devicesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init() {}

    deinit {
        stopMonitoring()
    }

    // MARK: - DeviceManager Protocol

    func startMonitoring() {
        // 立即获取一次电池信息
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
    }

    func refreshDevices() async {
        do {
            let batteryInfo = try getBatteryInfo()
            withLockedState {
                _devices = [batteryInfo]
            }
            devicesSubject.send([batteryInfo])
        } catch {
            // Log error and keep previous device list
            AppLogger.error("获取 Mac 电池信息失败: \(error.localizedDescription)", category: AppLogger.mac)
        }
    }

    func getDevice(by id: UUID) -> Device? {
        withLockedState {
            _devices.first { $0.id == id }
        }
    }

    // MARK: - Private Methods

    /// 获取 Mac 电池信息
    private func getBatteryInfo() throws -> Device {
        // 使用 IOKit 获取电池信息
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else {
            throw NSError(domain: "MacBatteryService", code: 1, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.power_source_unavailable")])
        }

        guard let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            throw NSError(domain: "MacBatteryService", code: 2, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.no_power_source")])
        }

        var batteryLevel = 100
        var isCharging = false
        var foundBattery = false

        for source in sources {
            if let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                // 只处理电池类型的电源
                if let type = info[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType {
                    foundBattery = true

                    // 获取电池电量
                    if let currentCapacity = info[kIOPSCurrentCapacityKey] as? Int,
                       let maxCapacity = info[kIOPSMaxCapacityKey] as? Int,
                       maxCapacity > 0 {
                        batteryLevel = min(100, max(0, (currentCapacity * 100) / maxCapacity))
                    }

                    // 获取充电状态
                    if let powerSourceState = info[kIOPSPowerSourceStateKey] as? String {
                        isCharging = (powerSourceState == kIOPSACPowerValue)
                    }

                    // 也可以通过 isCharging 键获取充电状态
                    if let charging = info[kIOPSIsChargingKey] as? Bool {
                        isCharging = charging
                    }

                    break
                }
            }
        }

        if !foundBattery {
            throw NSError(domain: "MacBatteryService", code: 3, userInfo: [NSLocalizedDescriptionKey: String(localized: "error.no_internal_battery")])
        }

        // 获取设备名称
        let deviceName = Host.current().localizedName ?? "Mac"

        return Device(
            id: getMacDeviceID(),
            name: deviceName,
            type: .mac,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            lastUpdated: Date()
        )
    }

    /// 获取 Mac 设备的唯一标识符
    /// 使用硬件 UUID 作为设备 ID
    private func getMacDeviceID() -> UUID {
        // 尝试从 UserDefaults 获取已保存的 UUID
        let key = "MacDeviceUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        // 如果没有保存过，创建新的 UUID 并保存
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }
}
