import Foundation
import IOKit
import IOKit.usb

/// iOS 设备事件监听器
/// 监听 USB 设备插拔事件，触发设备刷新
final class IOSDeviceEventMonitor {
    // MARK: - Properties

    private var notificationPort: IONotificationPortRef?
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private let onDeviceEvent: () -> Void

    // Apple Mobile Device USB VID
    private let appleVendorID: Int32 = 0x05AC

    // MARK: - Initialization

    init(onDeviceEvent: @escaping () -> Void) {
        self.onDeviceEvent = onDeviceEvent
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// 开始监听 USB 设备事件
    func startMonitoring() {
        // 创建通知端口
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort = notificationPort else {
            AppLogger.error("无法创建 IONotificationPort", category: AppLogger.ios)
            return
        }

        // 将通知端口添加到 RunLoop
        let runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)

        // 匹配 Apple USB 设备
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchingDict[kUSBVendorID] = appleVendorID

        // 注册设备添加通知
        let addedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<IOSDeviceEventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDeviceAdded(iterator: iterator)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let addResult = IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDict,
            addedCallback,
            selfPtr,
            &addedIterator
        )

        if addResult == KERN_SUCCESS {
            // 清空初始匹配（必须调用，否则不会收到后续通知）
            handleDeviceAdded(iterator: addedIterator)
            AppLogger.info("USB 设备监听已启动", category: AppLogger.ios)
        } else {
            AppLogger.error("注册 USB 设备添加通知失败: \(addResult)", category: AppLogger.ios)
        }

        // 注册设备移除通知
        let matchingDictRemoved = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchingDictRemoved[kUSBVendorID] = appleVendorID

        let removedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<IOSDeviceEventMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDeviceRemoved(iterator: iterator)
        }

        let removeResult = IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            matchingDictRemoved,
            removedCallback,
            selfPtr,
            &removedIterator
        )

        if removeResult == KERN_SUCCESS {
            // 清空初始匹配
            handleDeviceRemoved(iterator: removedIterator)
        } else {
            AppLogger.error("注册 USB 设备移除通知失败: \(removeResult)", category: AppLogger.ios)
        }
    }

    /// 停止监听
    func stopMonitoring() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }

        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }

        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }

        AppLogger.info("USB 设备监听已停止", category: AppLogger.ios)
    }

    // MARK: - Private Methods

    private func handleDeviceAdded(iterator: io_iterator_t) {
        var hasDevice = false
        while case let device = IOIteratorNext(iterator), device != 0 {
            hasDevice = true
            IOObjectRelease(device)
        }

        if hasDevice {
            AppLogger.debug("检测到 Apple USB 设备连接", category: AppLogger.ios)
            onDeviceEvent()
        }
    }

    private func handleDeviceRemoved(iterator: io_iterator_t) {
        var hasDevice = false
        while case let device = IOIteratorNext(iterator), device != 0 {
            hasDevice = true
            IOObjectRelease(device)
        }

        if hasDevice {
            AppLogger.debug("检测到 Apple USB 设备断开", category: AppLogger.ios)
            onDeviceEvent()
        }
    }
}
