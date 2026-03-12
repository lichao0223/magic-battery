import Combine
import Foundation

@MainActor
final class DeviceDetailsViewModel: ObservableObject {
    @Published private(set) var snapshot: DeviceDetailSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let device: Device
    private let service: DeviceDetailsService

    init(device: Device) {
        self.device = device
        self.service = DeviceDetailsService()
    }

    init(device: Device, service: DeviceDetailsService) {
        self.device = device
        self.service = service
    }

    func loadIfNeeded() async {
        guard snapshot == nil, !isLoading else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil

        do {
            snapshot = try await service.loadDetails(for: device)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
