import Combine
import Foundation

@MainActor
final class DeviceDetailsViewModel: ObservableObject {
    @Published private(set) var snapshot: DeviceDetailSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var historySamples: [BatteryHistorySample] = []

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

        async let historyTask = loadHistory()

        do {
            snapshot = try await service.loadDetails(for: device)
        } catch {
            snapshot = fallbackSnapshot(for: device)
            errorMessage = device.supportsBatteryDetails ? error.localizedDescription : nil
        }

        historySamples = await historyTask
        isLoading = false
    }

    private func loadHistory() async -> [BatteryHistorySample] {
        let since = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date().addingTimeInterval(-24 * 60 * 60)
        return await BatteryHistoryStore.shared.history(for: device.id, since: since)
    }

    private func fallbackSnapshot(for device: Device) -> DeviceDetailSnapshot {
        let batteryValue = device.isBatteryUnknown ? String(localized: "common.unknown") : "\(device.batteryLevel)%"
        let chargingValue = device.isCharging ? String(localized: "common.yes") : String(localized: "common.no")
        let updatedValue = DateFormatter.localizedString(from: device.lastUpdated, dateStyle: .none, timeStyle: .short)

        let sections = [
            DeviceDetailSection(
                id: "current_status",
                title: String(localized: "section.current_status"),
                items: [
                    DeviceDetailItem(id: "level", title: String(localized: "detail.level"), value: batteryValue),
                    DeviceDetailItem(id: "charging", title: String(localized: "detail.charging"), value: chargingValue),
                    DeviceDetailItem(id: "last_updated", title: String(localized: "detail.last_updated"), value: updatedValue)
                ]
            ),
            DeviceDetailSection(
                id: "device_info",
                title: String(localized: "section.device_info"),
                items: [
                    DeviceDetailItem(id: "device_name", title: String(localized: "detail.device_name"), value: device.name),
                    DeviceDetailItem(id: "device_source", title: String(localized: "detail.device_source"), value: device.sourceLabel ?? String(localized: "common.unknown")),
                    DeviceDetailItem(id: "identifier", title: String(localized: "detail.identifier"), value: device.externalIdentifier ?? device.id.uuidString, detail: device.parentExternalIdentifier)
                ]
            )
        ]

        return DeviceDetailSnapshot(
            subtitle: [device.type.displayName, device.sourceLabel].compactMap { $0 }.joined(separator: " · "),
            sections: sections,
            footnote: String(localized: "details.history_fallback_note")
        )
    }
}
