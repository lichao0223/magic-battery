import Foundation
import Combine
import SwiftUI

/// 设备列表视图模型
/// 负责管理设备列表的状态和业务逻辑
@MainActor
final class DeviceListViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var devices: [Device] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var sortOption: SortOption = .batteryLevel
    @Published var sortDirection: SortDirection = .ascending
    @Published var filterOption: FilterOption = .all

    // MARK: - Private Properties

    private let deviceManager: DeviceManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    /// 过滤和排序后的设备列表
    var filteredAndSortedDevices: [Device] {
        let filtered = filterDevices(devices)
        return sortDevices(filtered)
    }

    /// 分组后的设备列表
    var groupedDevices: [DeviceGroupSection] {
        let grouped = Dictionary(grouping: filteredAndSortedDevices, by: groupForDevice)
        return DeviceGroup.allCases.compactMap { group in
            guard let devices = grouped[group], !devices.isEmpty else { return nil }
            return DeviceGroupSection(group: group, devices: devices)
        }
    }

    /// 低电量阈值（用于 UI 过滤/统计）
    private var lowBatteryThreshold: Int {
        let configured = UserDefaults.standard.integer(forKey: "lowBatteryThreshold")
        return configured > 0 ? configured : 20
    }

    /// 低电量设备数量
    var lowBatteryDeviceCount: Int {
        devices.filter { $0.isLowBattery(threshold: lowBatteryThreshold) && !$0.isCharging }.count
    }

    /// 是否有低电量设备
    var hasLowBatteryDevices: Bool {
        lowBatteryDeviceCount > 0
    }

    // MARK: - Initialization

    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        setupBindings()
    }

    // MARK: - Public Methods

    /// 开始监控设备
    func startMonitoring() {
        deviceManager.startMonitoring()
    }

    /// 停止监控设备
    func stopMonitoring() {
        deviceManager.stopMonitoring()
    }

    /// 刷新设备列表
    func refreshDevices() async {
        isLoading = true
        errorMessage = nil

        do {
            await deviceManager.refreshDevices()
            isLoading = false
        } catch {
            errorMessage = String(localized: "error.device_refresh_failed")
            isLoading = false
        }
    }

    /// 获取特定设备
    func getDevice(by id: UUID) -> Device? {
        return deviceManager.getDevice(by: id)
    }

    func selectSortOption(_ option: SortOption) {
        if sortOption != option {
            sortOption = option
            sortDirection = option.defaultDirection
        }
    }

    func toggleSortDirection() {
        sortDirection = sortDirection == .ascending ? .descending : .ascending
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // 订阅设备管理器的设备更新
        deviceManager.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)
    }

    private func filterDevices(_ devices: [Device]) -> [Device] {
        switch filterOption {
        case .all:
            return devices
        case .lowBattery:
            return devices.filter { $0.isLowBattery(threshold: lowBatteryThreshold) }
        case .charging:
            return devices.filter { $0.isCharging }
        case .type(let deviceType):
            return devices.filter { $0.type == deviceType }
        }
    }

    private func sortDevices(_ devices: [Device]) -> [Device] {
        let sorted: [Device]
        switch sortOption {
        case .batteryLevel:
            sorted = devices.sorted {
                compareBatteryDevices($0, $1)
            }
        case .name:
            sorted = devices.sorted { compare(lhs: $0.name.localizedLowercase, rhs: $1.name.localizedLowercase) }
        case .lastUpdated:
            sorted = devices.sorted { compare(lhs: $0.lastUpdated, rhs: $1.lastUpdated) }
        case .deviceType:
            sorted = devices.sorted { compare(lhs: $0.type.displayName, rhs: $1.type.displayName) }
        }

        return sorted
    }

    private func groupForDevice(_ device: Device) -> DeviceGroup {
        switch device.type {
        case .mac:
            return .local
        case .iPhone, .iPad, .appleWatch, .airPods, .airPodsLeft, .airPodsRight, .airPodsCase:
            return .appleDevices
        default:
            return .accessories
        }
    }

    private func compare<T: Comparable>(lhs: T, rhs: T) -> Bool {
        switch sortDirection {
        case .ascending:
            return lhs < rhs
        case .descending:
            return lhs > rhs
        }
    }

    private func compareBatteryDevices(_ lhs: Device, _ rhs: Device) -> Bool {
        switch (lhs.isBatteryUnknown, rhs.isBatteryUnknown) {
        case (true, true):
            return compare(lhs: lhs.name.localizedLowercase, rhs: rhs.name.localizedLowercase)
        case (true, false):
            return false
        case (false, true):
            return true
        case (false, false):
            if lhs.batteryLevel == rhs.batteryLevel {
                return compare(lhs: lhs.name.localizedLowercase, rhs: rhs.name.localizedLowercase)
            }
            return compare(lhs: lhs.batteryLevel, rhs: rhs.batteryLevel)
        }
    }
}

// MARK: - Supporting Types

extension DeviceListViewModel {
    enum SortDirection: String, CaseIterable, Identifiable {
        case ascending
        case descending

        var id: String { rawValue }

        var title: String {
            switch self {
            case .ascending:
                return String(localized: "sort.ascending")
            case .descending:
                return String(localized: "sort.descending")
            }
        }

        var symbolName: String {
            switch self {
            case .ascending:
                return "arrow.up"
            case .descending:
                return "arrow.down"
            }
        }
    }

    struct DeviceGroupSection: Identifiable {
        let group: DeviceGroup
        let devices: [Device]

        var id: DeviceGroup { group }
        var title: String { group.title }
    }

    enum DeviceGroup: String, CaseIterable, Identifiable {
        case local
        case appleDevices
        case accessories

        var id: String { rawValue }

        var title: String {
            switch self {
            case .local:
                return String(localized: "group.local")
            case .appleDevices:
                return String(localized: "group.apple_devices")
            case .accessories:
                return String(localized: "group.accessories")
            }
        }
    }

    /// 排序选项
    enum SortOption: String, CaseIterable, Identifiable {
        case batteryLevel
        case name
        case lastUpdated
        case deviceType

        var id: String { rawValue }

        var menuTitle: String {
            switch self {
            case .batteryLevel:
                return String(localized: "sort.by_battery")
            case .name:
                return String(localized: "sort.by_name")
            case .lastUpdated:
                return String(localized: "sort.by_updated")
            case .deviceType:
                return String(localized: "sort.by_type")
            }
        }

        var symbolName: String {
            switch self {
            case .batteryLevel:
                return "battery.75"
            case .name:
                return "textformat"
            case .lastUpdated:
                return "clock"
            case .deviceType:
                return "square.grid.2x2"
            }
        }

        var defaultDirection: SortDirection {
            switch self {
            case .batteryLevel, .name, .deviceType:
                return .ascending
            case .lastUpdated:
                return .descending
            }
        }
    }

    /// 过滤选项
    enum FilterOption: Equatable, Identifiable {
        case all
        case lowBattery
        case charging
        case type(DeviceType)

        var id: String {
            switch self {
            case .all:
                return "all"
            case .lowBattery:
                return "lowBattery"
            case .charging:
                return "charging"
            case .type(let type):
                return "type_\(type.rawValue)"
            }
        }

        var displayName: String {
            switch self {
            case .all:
                return String(localized: "filter.all")
            case .lowBattery:
                return String(localized: "filter.low_battery")
            case .charging:
                return String(localized: "filter.charging")
            case .type(let type):
                return type.displayName
            }
        }
    }
}
