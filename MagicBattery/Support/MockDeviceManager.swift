import Foundation
import Combine

@MainActor
final class MockDeviceManager: DeviceManager {
    private let subject: CurrentValueSubject<[Device], Never>

    var devices: [Device] {
        subject.value
    }

    var devicesPublisher: AnyPublisher<[Device], Never> {
        subject.eraseToAnyPublisher()
    }

    init(devices: [Device]) {
        self.subject = CurrentValueSubject(devices)
    }

    convenience init() {
        self.init(devices: MockData.devices)
    }

    func startMonitoring() {
        subject.send(subject.value)
    }

    func stopMonitoring() {}

    func refreshDevices() async {
        subject.send(subject.value)
    }

    func getDevice(by id: UUID) -> Device? {
        subject.value.first(where: { $0.id == id })
    }
}
