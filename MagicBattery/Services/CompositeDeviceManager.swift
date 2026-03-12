import Foundation
import Combine

/// 复合设备管理器
/// 整合多个设备管理器，统一管理所有设备
final class CompositeDeviceManager: DeviceManager {
    // MARK: - Properties

    private let managers: [DeviceManager]
    private var cancellables = Set<AnyCancellable>()
    private let devicesSubject = CurrentValueSubject<[Device], Never>([])

    var devices: [Device] {
        return managers.flatMap { $0.devices }
    }

    var devicesPublisher: AnyPublisher<[Device], Never> {
        return devicesSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    init(managers: [DeviceManager]) {
        self.managers = managers
        setupPublishers()
    }

    // MARK: - DeviceManager Protocol

    func startMonitoring() {
        managers.forEach { $0.startMonitoring() }
    }

    func stopMonitoring() {
        managers.forEach { $0.stopMonitoring() }
    }

    func refreshDevices() async {
        await withTaskGroup(of: Void.self) { group in
            for manager in managers {
                group.addTask {
                    await manager.refreshDevices()
                }
            }
        }
        updateDevices()
    }

    func getDevice(by id: UUID) -> Device? {
        for manager in managers {
            if let device = manager.getDevice(by: id) {
                return device
            }
        }
        return nil
    }

    // MARK: - Private Methods

    private func setupPublishers() {
        // 订阅所有管理器的设备更新
        for manager in managers {
            manager.devicesPublisher
                .sink { [weak self] _ in
                    self?.updateDevices()
                }
                .store(in: &cancellables)
        }
    }

    private func updateDevices() {
        let allDevices = managers.flatMap { $0.devices }
        devicesSubject.send(allDevices)
    }
}
