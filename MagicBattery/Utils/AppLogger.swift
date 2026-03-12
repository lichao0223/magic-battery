import Foundation
import os.log

/// 统一日志系统
/// 使用 OSLog 替代 print，支持隐私保护和日志级别控制
enum AppLogger {
    // MARK: - Subsystems

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.lc.battery"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let bluetooth = Logger(subsystem: subsystem, category: "bluetooth")
    static let ios = Logger(subsystem: subsystem, category: "ios")
    static let mac = Logger(subsystem: subsystem, category: "mac")
    static let notification = Logger(subsystem: subsystem, category: "notification")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let permission = Logger(subsystem: subsystem, category: "permission")
    static let ui = Logger(subsystem: subsystem, category: "ui")

    // MARK: - Convenience Methods

    /// 记录调试信息（仅在 DEBUG 模式下输出）
    static func debug(_ message: String, category: Logger = app) {
        #if DEBUG
        category.debug("\(message, privacy: .public)")
        #endif
    }

    /// 记录一般信息
    static func info(_ message: String, category: Logger = app) {
        category.info("\(message, privacy: .public)")
    }

    /// 记录警告
    static func warning(_ message: String, category: Logger = app) {
        category.warning("\(message, privacy: .public)")
    }

    /// 记录错误
    static func error(_ message: String, category: Logger = app) {
        category.error("\(message, privacy: .public)")
    }

    /// 记录故障（严重错误）
    static func fault(_ message: String, category: Logger = app) {
        category.fault("\(message, privacy: .public)")
    }

    // MARK: - Privacy-Aware Logging

    /// 记录包含敏感信息的调试日志（UDID、设备名等）
    static func debugPrivate(_ message: String, category: Logger = app) {
        #if DEBUG
        category.debug("\(message, privacy: .private)")
        #endif
    }

    /// 记录包含敏感信息的信息日志
    static func infoPrivate(_ message: String, category: Logger = app) {
        category.info("\(message, privacy: .private)")
    }

    // MARK: - Utility Methods

    /// 脱敏 UDID（仅保留后 4 位）
    static func maskUDID(_ udid: String) -> String {
        guard udid.count > 4 else { return "****" }
        let suffix = udid.suffix(4)
        return "****\(suffix)"
    }

    /// 脱敏设备名（如果包含用户名等敏感信息）
    static func maskDeviceName(_ name: String) -> String {
        // 如果设备名包含 "的" 或 "'s"，可能包含用户名
        if name.contains("的") || name.contains("'s") {
            return "[设备]"
        }
        return name
    }
}
