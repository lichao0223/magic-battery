import SwiftUI
import Combine

@main
struct batteryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 隐藏主窗口，只显示菜单栏
        Settings {
            EmptyView()
        }
    }
}

/// 应用委托
/// 负责应用的生命周期管理和初始化
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager?
    private var deviceManager: DeviceManager?
    private var viewModel: DeviceListViewModel?
    private var cancellables = Set<AnyCancellable>()

    /// 是否在单元测试环境中运行
    private var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 单元测试环境下跳过所有硬件初始化，避免蓝牙/USB/通知等服务在 CI 上阻塞
        guard !isRunningTests else {
            AppLogger.info("Running under XCTest — skipping app initialization", category: AppLogger.app)
            return
        }

        if RuntimeFlags.exportScreenshots {
            NSApp.setActivationPolicy(.regular)
            MockData.applyScreenshotDefaults()
            Task {
                do {
                    let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                        .appendingPathComponent("docs/screenshots", isDirectory: true)
                    try await ScreenshotExporter.exportAll(into: outputDir)
                    AppLogger.info("Screenshot export completed", category: AppLogger.app)
                } catch {
                    AppLogger.error("Screenshot export failed: \(error.localizedDescription)", category: AppLogger.app)
                }
                NSApplication.shared.terminate(nil)
            }
            return
        }

        if RuntimeFlags.useMockData {
            MockData.applyScreenshotDefaults()
        }

        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")

        // 设置应用为菜单栏应用（可选在 Dock 中显示）
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        AppLogger.info("Setting activation policy to \(showInDock ? "regular" : "accessory")", category: AppLogger.app)

        // 初始化设备管理器
        setupDeviceManager()
        AppLogger.info("Device manager setup complete", category: AppLogger.app)

        // 初始化视图模型
        setupViewModel()
        AppLogger.info("ViewModel setup complete", category: AppLogger.app)

        // 初始化菜单栏
        setupMenuBar()
        AppLogger.info("MenuBar setup complete", category: AppLogger.app)

        if !RuntimeFlags.useMockData {
            // 请求通知权限
            requestNotificationPermission()
            AppLogger.info("Starting device monitoring...", category: AppLogger.app)
        } else {
            AppLogger.info("Starting in mock data mode", category: AppLogger.app)
        }

        // 开始监控设备
        deviceManager?.startMonitoring()

        // 设置通知监听
        setupNotificationMonitoring()

        // 设置小组件数据同步
        setupWidgetDataSync()

        // 记录设备电量历史
        setupHistoryRecording()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 停止监控
        deviceManager?.stopMonitoring()
    }

    // MARK: - Setup

    private func setupDeviceManager() {
        if RuntimeFlags.useMockData {
            deviceManager = MockDeviceManager()
            return
        }

        // 创建各个设备管理器
        let macBatteryService = MacBatteryService()
        let bluetoothService = BluetoothDeviceService()
        let iosDeviceService = IOSDeviceService()

        // 创建复合设备管理器
        deviceManager = CompositeDeviceManager(managers: [
            macBatteryService,
            bluetoothService,
            iosDeviceService
        ])
    }

    private func setupViewModel() {
        guard let deviceManager = deviceManager else { return }
        viewModel = DeviceListViewModel(deviceManager: deviceManager)
    }

    private func setupMenuBar() {
        guard let viewModel = viewModel else { return }
        menuBarManager = MenuBarManager(viewModel: viewModel)
    }

    private func requestNotificationPermission() {
        Task {
            let status = await PermissionManager.shared.requestNotificationPermission()
            if status.isGranted {
                AppLogger.info("通知权限已授予", category: AppLogger.notification)
            } else {
                AppLogger.warning("通知权限被拒绝", category: AppLogger.notification)
            }
        }
    }

    private func setupNotificationMonitoring() {
        guard let viewModel = viewModel, !RuntimeFlags.useMockData else { return }

        // 监听设备变化，自动发送低电量通知
        viewModel.$devices
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { devices in
                Task {
                    await NotificationManager.shared.updateDeviceStatus(devices)
                }
            }
            .store(in: &cancellables)
    }

    private func setupWidgetDataSync() {
        guard let viewModel = viewModel else { return }

        // 监听设备变化，同步数据到小组件
        viewModel.$devices
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { devices in
                WidgetDataManager.shared.saveDevices(devices)
            }
            .store(in: &cancellables)
    }

    private func setupHistoryRecording() {
        guard let viewModel = viewModel else { return }

        viewModel.$devices
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { devices in
                Task {
                    await BatteryHistoryStore.shared.record(devices: devices)
                }
            }
            .store(in: &cancellables)
    }
}
