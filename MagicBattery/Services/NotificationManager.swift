import Foundation
import UserNotifications

/// 通知管理器
/// 负责管理低电量通知和其他系统通知
final class NotificationManager: NSObject {
    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Properties

    private let notificationCenter = UNUserNotificationCenter.current()
    private var notifiedDevices = Set<UUID>() // 已通知过的设备ID
    private let notifiedDevicesLock = NSLock()

    private var lowBatteryThreshold: Int {
        let configured = UserDefaults.standard.integer(forKey: "lowBatteryThreshold")
        return configured > 0 ? configured : 20
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        notificationCenter.delegate = self
    }

    // MARK: - Public Methods

    /// 请求通知权限
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return try await notificationCenter.requestAuthorization(options: options)
    }

    /// 检查通知权限状态
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }

    /// 发送低电量通知
    /// - Parameter device: 低电量设备
    func sendLowBatteryNotification(for device: Device) async {
        // 如果设备正在充电，则不再发送通知
        guard !device.isCharging else {
            return
        }

        // 检查是否低于阈值
        guard device.batteryLevel < lowBatteryThreshold else {
            return
        }

        // 预占位，避免并发重复发送
        let reserved = notifiedDevicesLock.withLock {
            if notifiedDevices.contains(device.id) {
                return false
            }
            notifiedDevices.insert(device.id)
            return true
        }
        guard reserved else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.subtitle = String(localized: "notification.low_battery.subtitle")
        content.body = String(format: String(localized: "notification.low_battery.body"), device.name, device.batteryLevel)
        content.sound = .default
        content.categoryIdentifier = "LOW_BATTERY"
        content.userInfo = ["deviceId": device.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "low_battery_\(device.id.uuidString)",
            content: content,
            trigger: nil // 立即发送
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            // 发送失败需要回滚占位
            notifiedDevicesLock.withLock {
                notifiedDevices.remove(device.id)
            }
            AppLogger.error("发送通知失败: \(error.localizedDescription)", category: AppLogger.notification)
        }
    }

    /// 批量检查设备并发送低电量通知
    /// - Parameter devices: 设备列表
    func checkAndNotifyLowBattery(for devices: [Device]) async {
        for device in devices {
            await sendLowBatteryNotification(for: device)
        }
    }

    /// 清除设备的通知记录（当设备开始充电或电量恢复时调用）
    /// - Parameter deviceId: 设备ID
    func clearNotificationRecord(for deviceId: UUID) {
        notifiedDevicesLock.withLock {
            notifiedDevices.remove(deviceId)
        }

        // 移除该设备的待处理通知
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["low_battery_\(deviceId.uuidString)"]
        )

        // 移除该设备的已显示通知
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: ["low_battery_\(deviceId.uuidString)"]
        )
    }

    /// 清除所有通知记录
    func clearAllNotificationRecords() {
        notifiedDevicesLock.withLock {
            notifiedDevices.removeAll()
        }
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }

    /// 发送测试通知
    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.title")
        content.subtitle = String(localized: "notification.test.subtitle")
        content.body = String(localized: "notification.test.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "test_notification",
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            AppLogger.error("发送测试通知失败: \(error.localizedDescription)", category: AppLogger.notification)
        }
    }

    /// 更新设备状态并管理通知
    /// - Parameter devices: 当前设备列表
    func updateDeviceStatus(_ devices: [Device]) async {
        let notifiedSnapshot = notifiedDevicesLock.withLock { Array(notifiedDevices) }

        // 检查已通知的设备是否开始充电或电量恢复
        for deviceId in notifiedSnapshot {
            if let device = devices.first(where: { $0.id == deviceId }) {
                // 如果设备开始充电或电量恢复到阈值以上，清除通知记录
                if device.isCharging || device.batteryLevel >= lowBatteryThreshold {
                    clearNotificationRecord(for: deviceId)
                }
            } else {
                // 设备已断开连接，清除通知记录
                clearNotificationRecord(for: deviceId)
            }
        }

        // 检查并发送新的低电量通知
        await checkAndNotifyLowBattery(for: devices)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// 在前台显示通知
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 即使应用在前台也显示通知
        completionHandler([.banner, .sound, .badge])
    }

    /// 处理用户点击通知的响应
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // 获取设备ID
        if let deviceIdString = userInfo["deviceId"] as? String,
           let deviceId = UUID(uuidString: deviceIdString) {
            // 可以在这里处理用户点击通知后的操作
            // 例如：打开应用并显示该设备的详细信息
            AppLogger.debug("用户点击了设备通知", category: AppLogger.notification)
        }

        completionHandler()
    }
}
