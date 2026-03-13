import SwiftUI
import ServiceManagement

/// 设置视图
struct SettingsView: View {
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("lowBatteryThreshold") private var lowBatteryThreshold = 20
    @AppStorage("updateInterval") private var updateInterval = 60
    @AppStorage("bleScanInterval") private var bleScanInterval = 120
    @AppStorage("showInDock") private var showInDock = false
    @AppStorage("enableIDeviceDiscovery") private var enableIDeviceDiscovery = true
    @AppStorage("enableWatchBatteryDiscovery") private var enableWatchBatteryDiscovery = true
    @AppStorage("showOfflineIDevices") private var showOfflineIDevices = true
    @AppStorage("appearanceMode") private var appearanceMode = 0

    @Environment(\.dismiss) private var dismiss

    private var appShortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var appBuildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
    }

    private var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }


    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 16) {
                    settingsContent
                }
            } else {
                settingsContent
            }
        }
        .frame(width: 512, height: 560)
        .preferredColorScheme(resolvedColorScheme)
        .padding(14)
        .background(BatteryAtmosphereBackground())
        .batteryPanelSurface(cornerRadius: 32, tint: Color.white.opacity(0.08))
    }

    private var settingsContent: some View {
        VStack(spacing: 0) {
            headerView

            BatteryHairline()
                .padding(.horizontal, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    notificationSection
                    updateSection
                    bleSection
                    appleDevicesSection
                    appSection
                    aboutSection
                }
                .padding(18)
            }

            BatteryHairline()
                .padding(.horizontal, 16)

            footerView
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            MagicBatteryMark(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("settings.title")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("settings.subtitle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
            }
            .batterySecondaryControlStyle(compact: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        sectionCard(
            title: "settings.notification.title",
            subtitle: "settings.notification.subtitle"
        ) {
            Toggle("settings.notification.enable", isOn: $enableNotifications)
                .toggleStyle(.switch)

            if enableNotifications {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("settings.notification.threshold")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.primary.opacity(0.85))

                        Spacer()

                        Text("\(lowBatteryThreshold)%")
                            .font(.system(size: 12, weight: .semibold))
                            .batteryToolbarChip(
                                tint: Color.mint.opacity(0.16),
                                foreground: Color.primary.opacity(0.85)
                            )
                    }

                    Slider(value: Binding(
                        get: { Double(lowBatteryThreshold) },
                        set: { lowBatteryThreshold = Int($0) }
                    ), in: 10...50, step: 5)

                    Text("settings.notification.threshold.description")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Button(action: {
                Task {
                    await NotificationManager.shared.sendTestNotification()
                }
            }) {
                Label("settings.notification.test", systemImage: "bell.badge")
            }
            .batterySecondaryControlStyle()
        }
    }

    // MARK: - Update Section

    private var updateSection: some View {
        sectionCard(
            title: "settings.update.title",
            subtitle: "settings.update.subtitle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("settings.update.interval")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))

                    Spacer()

                    Text(String(format: String(localized: "settings.seconds_format"), updateInterval))
                        .font(.system(size: 12, weight: .semibold))
                        .batteryToolbarChip(
                            tint: Color.cyan.opacity(0.14),
                            foreground: Color.primary.opacity(0.85)
                        )
                }

                Slider(value: Binding(
                    get: { Double(updateInterval) },
                    set: { updateInterval = Int($0) }
                ), in: 30...300, step: 30)

                Text("settings.update.interval.description")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - BLE Section

    private var bleSection: some View {
        sectionCard(
            title: "settings.ble.title",
            subtitle: "settings.ble.subtitle"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("settings.ble.interval")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))

                    Spacer()

                    Text(String(format: String(localized: "settings.seconds_format"), bleScanInterval))
                        .font(.system(size: 12, weight: .semibold))
                        .batteryToolbarChip(
                            tint: Color.purple.opacity(0.14),
                            foreground: Color.primary.opacity(0.85)
                        )
                }

                Slider(value: Binding(
                    get: { Double(bleScanInterval) },
                    set: { bleScanInterval = Int($0) }
                ), in: 60...300, step: 30)

                Text("settings.ble.interval.description")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        sectionCard(
            title: "settings.app.title",
            subtitle: "settings.app.subtitle"
        ) {
            Toggle("settings.app.show_in_dock", isOn: $showInDock)
                .toggleStyle(.switch)
                .onChange(of: showInDock) { _, newValue in
                    NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                }

            Toggle("settings.app.launch_at_login", isOn: Binding(
                get: { isLaunchAtLoginEnabled },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        AppLogger.error("设置登录启动失败: \(error.localizedDescription)", category: AppLogger.app)
                    }
                }
            ))
            .toggleStyle(.switch)

            Picker(selection: $appearanceMode) {
                Text("settings.app.appearance.system").tag(0)
                Text("settings.app.appearance.light").tag(1)
                Text("settings.app.appearance.dark").tag(2)
            } label: {
                Text("settings.app.appearance")
                    .font(.system(size: 12, weight: .medium))
            }
            .pickerStyle(.segmented)

            Text("settings.app.launch_description")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Apple Devices Section

    private var appleDevicesSection: some View {
        sectionCard(
            title: "settings.apple_devices.title",
            subtitle: "settings.apple_devices.subtitle"
        ) {
            Toggle("settings.apple_devices.enable_idevice", isOn: $enableIDeviceDiscovery)
                .toggleStyle(.switch)

            Toggle("settings.apple_devices.enable_watch", isOn: $enableWatchBatteryDiscovery)
                .toggleStyle(.switch)
                .disabled(!enableIDeviceDiscovery)

            Toggle("settings.apple_devices.show_offline", isOn: $showOfflineIDevices)
                .toggleStyle(.switch)
                .disabled(!enableIDeviceDiscovery)

            VStack(alignment: .leading, spacing: 6) {
                Text("settings.apple_devices.iphone_note")
                Text("settings.apple_devices.watch_note")
                Text("settings.apple_devices.network_note")
            }
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        sectionCard(
            title: "settings.about.title",
            subtitle: "settings.about.subtitle"
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("settings.about.version")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(appShortVersion)
                        .font(.system(size: 12))
                }

                HStack {
                    Text("settings.about.build")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(appBuildVersion)
                        .font(.system(size: 12))
                }

                Text("settings.about.description")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Button(action: {
                resetToDefaults()
            }) {
                Label("settings.footer.reset", systemImage: "arrow.counterclockwise")
            }
            .batterySecondaryControlStyle()

            Spacer()

            Button(action: {
                dismiss()
            }) {
                Label("settings.footer.done", systemImage: "checkmark")
            }
            .batteryProminentControlStyle()
        }
        .padding(12)
        .batterySectionSurface(cornerRadius: 22)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: - Private Methods

    private func resetToDefaults() {
        enableNotifications = true
        lowBatteryThreshold = 20
        updateInterval = 60
        bleScanInterval = 120
        showInDock = false
        NSApp.setActivationPolicy(.accessory)
        try? SMAppService.mainApp.unregister()
        enableIDeviceDiscovery = true
        enableWatchBatteryDiscovery = true
        showOfflineIDevices = true
        appearanceMode = 0
    }

    private func sectionCard<Content: View>(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }

            content()
        }
        .padding(16)
        .batteryCardSurface(cornerRadius: 22, tint: Color.white.opacity(0.04))
    }
}

#Preview {
    SettingsView()
}
