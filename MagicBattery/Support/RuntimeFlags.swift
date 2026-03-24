import Foundation

@MainActor
enum RuntimeFlags {
    static var useMockData: Bool {
        ProcessInfo.processInfo.environment["MAGIC_BATTERY_USE_MOCK_DATA"] == "1"
    }

    static var exportScreenshots: Bool {
        ProcessInfo.processInfo.environment["MAGIC_BATTERY_EXPORT_SCREENSHOTS"] == "1"
    }
}
