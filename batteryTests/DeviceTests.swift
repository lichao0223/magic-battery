import XCTest
import SwiftUI
@testable import MagicBattery

final class DeviceTests: XCTestCase {

    // MARK: - Device Creation Tests

    func testDeviceCreation() {
        // Given
        let id = UUID()
        let name = "MacBook Pro"
        let type = DeviceType.mac
        let batteryLevel = 85
        let isCharging = true
        let lastUpdated = Date()

        // When
        let device = Device(
            id: id,
            name: name,
            type: type,
            batteryLevel: batteryLevel,
            isCharging: isCharging,
            lastUpdated: lastUpdated
        )

        // Then
        XCTAssertEqual(device.id, id)
        XCTAssertEqual(device.name, name)
        XCTAssertEqual(device.type, type)
        XCTAssertEqual(device.batteryLevel, batteryLevel)
        XCTAssertEqual(device.isCharging, isCharging)
        XCTAssertEqual(device.lastUpdated, lastUpdated)
    }

    // MARK: - Battery Level Validation Tests

    func testBatteryLevelValidation_WithinRange() {
        // Given
        let validLevels = [0, 50, 100]

        // When & Then
        for level in validLevels {
            let device = Device(
                id: UUID(),
                name: "Test Device",
                type: .mac,
                batteryLevel: level,
                isCharging: false,
                lastUpdated: Date()
            )
            XCTAssertEqual(device.batteryLevel, level, "Battery level \(level) should remain unchanged")
        }
    }

    func testBatteryLevelValidation_ClampedToMinimum() {
        // Given
        // Test that -1 stays as -1 (unknown battery)
        let unknownDevice = Device(
            id: UUID(),
            name: "Test Device",
            type: .mac,
            batteryLevel: -1,
            isCharging: false,
            lastUpdated: Date()
        )
        XCTAssertEqual(unknownDevice.batteryLevel, -1, "Battery level -1 should remain as -1 (unknown)")

        // Test that values below -1 are clamped to -1
        let belowMinimumLevels = [-10, -100]
        for level in belowMinimumLevels {
            let device = Device(
                id: UUID(),
                name: "Test Device",
                type: .mac,
                batteryLevel: level,
                isCharging: false,
                lastUpdated: Date()
            )
            XCTAssertEqual(device.batteryLevel, -1, "Battery level \(level) should be clamped to -1")
        }
    }

    func testBatteryLevelValidation_ClampedToMaximum() {
        // Given
        let aboveMaximumLevels = [101, 150, 200]

        // When & Then
        for level in aboveMaximumLevels {
            let device = Device(
                id: UUID(),
                name: "Test Device",
                type: .mac,
                batteryLevel: level,
                isCharging: false,
                lastUpdated: Date()
            )
            XCTAssertEqual(device.batteryLevel, 100, "Battery level \(level) should be clamped to 100")
        }
    }

    func testUnknownBatteryLevel() {
        // Test that isBatteryUnknown property works correctly
        let unknownDevice = Device(
            id: UUID(),
            name: "Test Device",
            type: .mac,
            batteryLevel: -1,
            isCharging: false,
            lastUpdated: Date()
        )
        XCTAssertTrue(unknownDevice.isBatteryUnknown, "Device with battery level -1 should have unknown battery")
        XCTAssertFalse(unknownDevice.isLowBattery, "Unknown battery should not be considered low battery")
        XCTAssertFalse(unknownDevice.isLowBattery(threshold: 20), "Unknown battery should not be considered low battery")

        let knownDevice = Device(
            id: UUID(),
            name: "Test Device",
            type: .mac,
            batteryLevel: 50,
            isCharging: false,
            lastUpdated: Date()
        )
        XCTAssertFalse(knownDevice.isBatteryUnknown, "Device with battery level 50 should not have unknown battery")
    }

    // MARK: - Device Type Tests

    func testDeviceTypeDisplayNames() {
        // Test that all device types have non-empty display names
        for type in DeviceType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type.rawValue) should have a display name")
        }
        // Verify universal display names stay consistent
        XCTAssertEqual(DeviceType.mac.displayName, "Mac")
        XCTAssertEqual(DeviceType.iPhone.displayName, "iPhone")
        XCTAssertEqual(DeviceType.iPad.displayName, "iPad")
    }

    // MARK: - Device Icon Tests

    func testDeviceIcons() {
        // Test Phase 1 device icon mapping
        let macDevice = Device(id: UUID(), name: "Mac", type: .mac, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(macDevice.icon, DeviceIcon.mac)

        let iPhoneDevice = Device(id: UUID(), name: "iPhone", type: .iPhone, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(iPhoneDevice.icon, DeviceIcon.iPhone)

        let iPadDevice = Device(id: UUID(), name: "iPad", type: .iPad, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(iPadDevice.icon, DeviceIcon.iPad)

        let watchDevice = Device(id: UUID(), name: "Apple Watch", type: .appleWatch, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(watchDevice.icon, DeviceIcon.appleWatch)

        let airPodsDevice = Device(id: UUID(), name: "AirPods", type: .airPods, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(airPodsDevice.icon, DeviceIcon.airPods)

        let keyboardDevice = Device(id: UUID(), name: "Keyboard", type: .bluetoothKeyboard, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(keyboardDevice.icon, DeviceIcon.keyboard)

        let mouseDevice = Device(id: UUID(), name: "Mouse", type: .bluetoothMouse, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(mouseDevice.icon, DeviceIcon.mouse)

        let headphoneDevice = Device(id: UUID(), name: "Headphone", type: .bluetoothHeadphone, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(headphoneDevice.icon, DeviceIcon.headphone)
    }

    // MARK: - Computed Properties Tests

    func testIsLowBattery() {
        // Test low battery threshold (20%)
        let lowBatteryDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 19, isCharging: false, lastUpdated: Date())
        XCTAssertTrue(lowBatteryDevice.isLowBattery)
        XCTAssertTrue(lowBatteryDevice.isLowBattery(threshold: 20))

        let normalBatteryDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 20, isCharging: false, lastUpdated: Date())
        XCTAssertFalse(normalBatteryDevice.isLowBattery)
        XCTAssertFalse(normalBatteryDevice.isLowBattery(threshold: 20))

        let highBatteryDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertFalse(highBatteryDevice.isLowBattery)
        XCTAssertFalse(highBatteryDevice.isLowBattery(threshold: 20))

        // Custom threshold
        let threshold30Device = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 29, isCharging: false, lastUpdated: Date())
        XCTAssertTrue(threshold30Device.isLowBattery(threshold: 30))
        XCTAssertFalse(threshold30Device.isLowBattery(threshold: 29))
    }

    func testBatteryColor() {
        // Test battery color based on level (default threshold = 20)
        let criticalDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 10, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(criticalDevice.batteryColor, .red)

        let lowDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 25, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(lowDevice.batteryColor, .orange)

        let normalDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 50, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(normalDevice.batteryColor, .green)

        let highDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 100, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(highDevice.batteryColor, .green)
    }

    func testBatteryColorWithCustomThreshold() {
        // Test that batteryColor respects custom threshold
        let device25 = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: 25, isCharging: false, lastUpdated: Date())

        // With threshold 20: 25 is in "warning" zone (orange)
        XCTAssertEqual(device25.batteryColor(lowThreshold: 20), .orange)

        // With threshold 30: 25 is in "critical" zone (red)
        XCTAssertEqual(device25.batteryColor(lowThreshold: 30), .red)

        // With threshold 10: 25 is well above warning (green)
        XCTAssertEqual(device25.batteryColor(lowThreshold: 10), .green)

        // Unknown battery
        let unknownDevice = Device(id: UUID(), name: "Test", type: .mac, batteryLevel: -1, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(unknownDevice.batteryColor(lowThreshold: 20), .secondary)
    }

    func testDefaultDeviceSourceInference() {
        let macDevice = Device(id: UUID(), name: "Mac", type: .mac, batteryLevel: 80, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(macDevice.source, .mac)

        let bluetoothDevice = Device(id: UUID(), name: "Mouse", type: .bluetoothMouse, batteryLevel: 80, isCharging: false, lastUpdated: Date())
        XCTAssertEqual(bluetoothDevice.source, .bluetooth)
    }

    func testDeviceDecodingBackwardsCompatibility() throws {
        let json = """
        {
          "id":"AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
          "name":"Old Device",
          "type":"mac",
          "batteryLevel":55,
          "isCharging":false,
          "lastUpdated":"2026-03-11T00:00:00Z"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let device = try decoder.decode(Device.self, from: Data(json.utf8))

        XCTAssertEqual(device.name, "Old Device")
        XCTAssertEqual(device.source, .mac)
        XCTAssertNil(device.externalIdentifier)
        XCTAssertFalse(device.isStale)
    }

    func testDeviceEncodingRoundtrip() throws {
        let original = Device(
            id: UUID(),
            name: "Test Phone",
            type: .iPhone,
            batteryLevel: 72,
            isCharging: true,
            lastUpdated: Date(),
            externalIdentifier: "abc123",
            source: .libimobiledeviceUSB,
            detailText: "Connected via USB"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Device.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.type, original.type)
        XCTAssertEqual(decoded.batteryLevel, original.batteryLevel)
        XCTAssertEqual(decoded.isCharging, original.isCharging)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.externalIdentifier, original.externalIdentifier)
        XCTAssertEqual(decoded.detailText, original.detailText)
    }

    func testStaleDeviceStatus() {
        let staleDevice = Device(
            id: UUID(),
            name: "iPhone",
            type: .iPhone,
            batteryLevel: 50,
            isCharging: false,
            lastUpdated: Date(),
            source: .libimobiledeviceNetwork,
            isStale: true
        )

        XCTAssertTrue(staleDevice.isStale)
        XCTAssertNotNil(staleDevice.statusText)

        let freshDevice = Device(
            id: UUID(),
            name: "iPhone",
            type: .iPhone,
            batteryLevel: 50,
            isCharging: false,
            lastUpdated: Date(),
            source: .libimobiledeviceNetwork,
            isStale: false
        )

        XCTAssertFalse(freshDevice.isStale)
    }

    func testDeviceSourceDisplayNames() {
        // Mac source should not show a label
        XCTAssertNil(DeviceSource.mac.displayName)

        // All other sources should have display names
        XCTAssertNotNil(DeviceSource.bluetooth.displayName)
        XCTAssertNotNil(DeviceSource.libimobiledeviceUSB.displayName)
        XCTAssertNotNil(DeviceSource.libimobiledeviceNetwork.displayName)
        XCTAssertNotNil(DeviceSource.companionProxy.displayName)
    }

    // MARK: - IDeviceTool Tests

    func testIDeviceToolExecutableNames() {
        XCTAssertEqual(IDeviceTool.ideviceID.executableName, "idevice_id")
        XCTAssertEqual(IDeviceTool.ideviceInfo.executableName, "ideviceinfo")
        XCTAssertEqual(IDeviceTool.ideviceDiagnostics.executableName, "idevicediagnostics")
    }

    func testIDeviceToolErrorDescriptions() {
        let toolNotFound = IDeviceToolError.toolNotFound(.ideviceID, ["/usr/bin/idevice_id"])
        XCTAssertNotNil(toolNotFound.errorDescription)

        let executionFailed = IDeviceToolError.executionFailed(.ideviceInfo, 1, "err")
        XCTAssertNotNil(executionFailed.errorDescription)

        let timedOut = IDeviceToolError.timedOut(.ideviceInfo, 10)
        XCTAssertNotNil(timedOut.errorDescription)

        let launchFailed = IDeviceToolError.processLaunchFailed(.ideviceID, "not found")
        XCTAssertNotNil(launchFailed.errorDescription)
    }

}
