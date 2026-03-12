import SwiftUI
import Combine

/// 菜单栏管理器
/// 负责管理菜单栏图标和弹出窗口
@MainActor
final class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let viewModel: DeviceListViewModel
    private var lastIconSignature: String?

    init(viewModel: DeviceListViewModel) {
        self.viewModel = viewModel
        setupMenuBar()
        setupPopover()
    }

    // MARK: - Setup

    private func setupMenuBar() {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        AppLogger.debug("Creating status item...", category: AppLogger.ui)
        if let button = statusItem?.button {
            updateMenuBarIcon()
            AppLogger.debug("Status item created successfully", category: AppLogger.ui)
            button.action = #selector(togglePopover)
            button.target = self
        }

        // 监听设备变化以更新图标
        viewModel.$devices
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 402, height: 642)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(viewModel: viewModel)
        )
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Menu Bar Icon

    private func updateMenuBarIcon() {
        AppLogger.debug("Updating menu bar icon, devices count: \(viewModel.devices.count)", category: AppLogger.ui)
        guard let button = statusItem?.button else { return }

        // 获取 Mac 设备的电池信息
        let macDevice = viewModel.devices.first { $0.type == .mac }

        if let device = macDevice {
            let signature = "\(device.batteryLevel)|\(device.isCharging)"
            guard signature != lastIconSignature else { return }
            lastIconSignature = signature

            // 显示电池电量百分比
            let batteryLevel = device.batteryLevel
            let isCharging = device.isCharging

            // 创建图标
            let icon = createBatteryIcon(level: batteryLevel, isCharging: isCharging)
            button.image = icon
            button.imagePosition = .imageLeading

            // 设置工具提示
            button.toolTip = isCharging
                ? String(format: String(localized: "menubar.tooltip_charging"), device.name, batteryLevel)
                : String(format: String(localized: "menubar.tooltip"), device.name, batteryLevel)
        } else {
            guard lastIconSignature != "default" else { return }
            lastIconSignature = "default"

            // 没有设备时显示默认图标
            button.image = NSImage(systemSymbolName: "battery.100", accessibilityDescription: String(localized: "menubar.battery"))
            button.toolTip = "MagicBattery"
        }
    }

    private func createBatteryIcon(level: Int, isCharging: Bool) -> NSImage? {
        // 根据电量选择图标
        let symbolName: String
        if isCharging {
            symbolName = "bolt.fill"
        } else if level <= 20 {
            symbolName = "battery.0"
        } else if level <= 50 {
            symbolName = "battery.25"
        } else if level <= 75 {
            symbolName = "battery.50"
        } else {
            symbolName = "battery.100"
        }

        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: String(localized: "menubar.battery"))?
            .withSymbolConfiguration(config)

        // 设置图标颜色
        if let image = image {
            image.isTemplate = true
        }

        return image
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover, popover.isShown {
            popover.performClose(nil)
        } else {
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // 激活应用以确保弹出窗口获得焦点
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showPopover() {
        guard let button = statusItem?.button else { return }
        popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hidePopover() {
        popover?.performClose(nil)
    }
}
