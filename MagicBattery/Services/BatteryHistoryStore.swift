import Foundation

struct BatteryHistorySample: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let batteryLevel: Int
    let isCharging: Bool

    init(id: UUID = UUID(), timestamp: Date, batteryLevel: Int, isCharging: Bool) {
        self.id = id
        self.timestamp = timestamp
        self.batteryLevel = batteryLevel
        self.isCharging = isCharging
    }
}

actor BatteryHistoryStore {
    static let shared = BatteryHistoryStore()

    private struct PersistedHistory: Codable {
        var devices: [String: [BatteryHistorySample]]
    }

    private var cache: [String: [BatteryHistorySample]] = [:]
    private var hasLoaded = false

    private let retentionWindow: TimeInterval = 7 * 24 * 60 * 60
    private let duplicateWindow: TimeInterval = 30 * 60
    private let maxSamplesPerDevice = 512

    func record(devices: [Device], at timestamp: Date = Date()) async {
        await ensureLoaded()

        let validDevices = devices.filter { $0.batteryLevel >= 0 }
        guard !validDevices.isEmpty else { return }

        var changed = false

        for device in validDevices {
            let key = device.id.uuidString
            var samples = cache[key] ?? []
            samples = trim(samples, now: timestamp)

            let shouldAppend: Bool
            if let last = samples.last {
                shouldAppend = last.batteryLevel != device.batteryLevel
                    || last.isCharging != device.isCharging
                    || timestamp.timeIntervalSince(last.timestamp) >= duplicateWindow
            } else {
                shouldAppend = true
            }

            guard shouldAppend else {
                cache[key] = samples
                continue
            }

            samples.append(
                BatteryHistorySample(
                    timestamp: timestamp,
                    batteryLevel: device.batteryLevel,
                    isCharging: device.isCharging
                )
            )
            if samples.count > maxSamplesPerDevice {
                samples = Array(samples.suffix(maxSamplesPerDevice))
            }
            cache[key] = samples
            changed = true
        }

        if changed {
            await save()
        }
    }

    func history(for deviceID: UUID, since: Date) async -> [BatteryHistorySample] {
        await ensureLoaded()
        let key = deviceID.uuidString
        let samples = trim(cache[key] ?? [], now: Date())
        cache[key] = samples
        return samples.filter { $0.timestamp >= since }.sorted { $0.timestamp < $1.timestamp }
    }

    private func trim(_ samples: [BatteryHistorySample], now: Date) -> [BatteryHistorySample] {
        let cutoff = now.addingTimeInterval(-retentionWindow)
        return samples.filter { $0.timestamp >= cutoff }
    }

    private func ensureLoaded() async {
        guard !hasLoaded else { return }
        defer { hasLoaded = true }

        do {
            let url = try storageURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                cache = [:]
                return
            }

            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let persisted = try decoder.decode(PersistedHistory.self, from: data)
            cache = persisted.devices
        } catch {
            cache = [:]
            AppLogger.warning("加载电量历史失败：\(error.localizedDescription)", category: AppLogger.app)
        }
    }

    private func save() async {
        do {
            let url = try storageURL()
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let persisted = PersistedHistory(devices: cache)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(persisted)
            try data.write(to: url, options: .atomic)
        } catch {
            AppLogger.error("保存电量历史失败：\(error.localizedDescription)", category: AppLogger.app)
        }
    }

    private func storageURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("MagicBattery", isDirectory: true)
            .appendingPathComponent("battery-history.json")
    }
}
