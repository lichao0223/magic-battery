import Foundation
import AppKit
import ApplicationServices
import UserNotifications
import CoreBluetooth

/// 权限管理器
/// 负责管理应用所需的各种系统权限
final class PermissionManager {
    // MARK: - Singleton

    static let shared = PermissionManager()

    private init() {}

    // MARK: - Notification Permission

    /// 检查通知权限状态
    func checkNotificationPermission() async -> PermissionStatus {
        let status = await NotificationManager.shared.checkAuthorizationStatus()

        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .provisional:
            return .granted
        @unknown default:
            return .notDetermined
        }
    }

    /// 请求通知权限
    func requestNotificationPermission() async -> PermissionStatus {
        do {
            let granted = try await NotificationManager.shared.requestAuthorization()
            return granted ? .granted : .denied
        } catch {
            AppLogger.error("请求通知权限失败: \(error.localizedDescription)", category: AppLogger.permission)
            return .denied
        }
    }

    // MARK: - Bluetooth Permission

    /// 检查蓝牙权限状态
    /// 注意：macOS 的蓝牙权限在首次使用时自动请求
    func checkBluetoothPermission() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            switch CBManager.authorization {
            case .allowedAlways:
                return .granted
            case .denied, .restricted:
                return .denied
            case .notDetermined:
                return .notDetermined
            @unknown default:
                return .notDetermined
            }
        }
        return .notDetermined
    }

    // MARK: - Accessibility Permission

    /// 检查辅助功能权限（如果需要）
    func checkAccessibilityPermission() -> PermissionStatus {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return trusted ? .granted : .denied
    }

    /// 请求辅助功能权限
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - All Permissions

    /// 检查所有必需权限
    func checkAllPermissions() async -> [PermissionType: PermissionStatus] {
        var permissions: [PermissionType: PermissionStatus] = [:]

        // 检查通知权限
        permissions[.notification] = await checkNotificationPermission()

        // 检查蓝牙权限
        permissions[.bluetooth] = checkBluetoothPermission()

        return permissions
    }

    /// 请求所有必需权限
    func requestAllPermissions() async {
        // 请求通知权限
        _ = await requestNotificationPermission()

        // 蓝牙权限会在首次使用时自动请求
    }

    /// 打开系统设置以手动授予权限
    func openSystemSettings(for type: PermissionType) {
        switch type {
        case .notification:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                NSWorkspace.shared.open(url)
            }
        case .bluetooth:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
                NSWorkspace.shared.open(url)
            }
        case .accessibility:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Supporting Types

/// 权限类型
enum PermissionType: String, CaseIterable {
    case notification
    case bluetooth
    case accessibility

    var displayName: String {
        switch self {
        case .notification:
            return String(localized: "permission.notification.title")
        case .bluetooth:
            return String(localized: "permission.bluetooth.title")
        case .accessibility:
            return String(localized: "permission.accessibility.title")
        }
    }

    var description: String {
        switch self {
        case .notification:
            return String(localized: "permission.notification.description")
        case .bluetooth:
            return String(localized: "permission.bluetooth.description")
        case .accessibility:
            return String(localized: "permission.accessibility.description")
        }
    }

    var isRequired: Bool {
        switch self {
        case .notification, .bluetooth:
            return true
        case .accessibility:
            return false
        }
    }
}

/// 权限状态
enum PermissionStatus: String {
    case granted
    case denied
    case notDetermined

    var displayName: String {
        switch self {
        case .granted:
            return String(localized: "permission.status.granted")
        case .denied:
            return String(localized: "permission.status.denied")
        case .notDetermined:
            return String(localized: "permission.status.not_determined")
        }
    }

    var isGranted: Bool {
        return self == .granted
    }
}
