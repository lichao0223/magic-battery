import SwiftUI

/// 菜单栏弹出视图
/// 显示所有设备的电池状态
struct MenuBarPopoverView: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @State private var showSettings = false
    @State private var selectedDevice: Device?
    @AppStorage("appearanceMode") private var appearanceMode = 0

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
                GlassEffectContainer(spacing: 14) {
                    panelContent
                }
            } else {
                panelContent
            }
        }
        .frame(width: 382, height: 622, alignment: .top)
        .padding(10)
        .background(BatteryAtmosphereBackground())
        .batteryPanelSurface(cornerRadius: 30, tint: Color.white.opacity(0.08))
        .preferredColorScheme(resolvedColorScheme)
        .sheet(item: $selectedDevice) { device in
            DeviceDetailsSheet(device: device)
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            headerView

            BatteryHairline()
                .padding(.horizontal, 12)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)

            BatteryHairline()
                .padding(.horizontal, 12)

            footerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            MagicBatteryMark(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("app.name")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text(headerSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 10)

            if viewModel.hasLowBatteryDevices {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text(String(format: String(localized: "popover.low_battery_count"), viewModel.lowBatteryDeviceCount))
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
                .batteryToolbarChip(
                    tint: Color.orange.opacity(0.18),
                    foreground: Color(red: 0.72, green: 0.34, blue: 0.04)
                )
            }

            Button(action: {
                Task {
                    await viewModel.refreshDevices()
                }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                    .animation(
                        viewModel.isLoading
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: viewModel.isLoading
                    )
            }
            .disabled(viewModel.isLoading)
            .batterySecondaryControlStyle(compact: true)
            .help(String(localized: "popover.refresh_help"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Device List View

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.groupedDevices.isEmpty {
            emptyView
        } else {
            deviceListView
        }
    }

    private var deviceListView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groupedDevices) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader(title: section.title, count: section.devices.count)

                        ForEach(section.devices) { device in
                            DeviceRowView(
                                device: device,
                                onTap: device.supportsBatteryDetails ? {
                                    selectedDevice = device
                                } : nil
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("popover.loading")
                .font(.system(size: 12))
                .foregroundColor(Color.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.horizontal, 16)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            MagicBatteryMark(size: 60)
            Text("popover.empty.title")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.primary)
            Text("popover.empty.subtitle")
                .font(.system(size: 11))
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(.horizontal, 16)
    }

    // MARK: - Footer View

    private var footerView: some View {
        HStack {
            Menu {
                ForEach(DeviceListViewModel.SortOption.allCases) { option in
                    Button {
                        viewModel.selectSortOption(option)
                    } label: {
                        HStack {
                            Label(option.menuTitle, systemImage: option.symbolName)

                            Spacer()

                            if option == viewModel.sortOption {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortOption.symbolName)
                        .font(.system(size: 11))
                    Text(viewModel.sortOption.menuTitle)
                        .font(.system(size: 11))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .frame(minWidth: 82)
            }
            .menuStyle(.borderlessButton)
            .batterySecondaryControlStyle(compact: true)

            Button(action: {
                viewModel.toggleSortDirection()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.sortDirection.symbolName)
                        .font(.system(size: 11, weight: .semibold))
                    Text(viewModel.sortDirection.title)
                        .font(.system(size: 11))
                }
                .frame(minWidth: 56)
            }
            .batterySecondaryControlStyle(compact: true)
            .help(String(localized: "sort.toggle_help"))

            Spacer()

            Button(action: {
                showSettings = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("popover.settings")
                        .font(.system(size: 11))
                }
            }
            .batterySecondaryControlStyle(compact: true)
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text("popover.quit")
                        .font(.system(size: 11))
                }
            }
            .batteryDestructiveControlStyle(compact: true)
        }
        .padding(8)
        .batterySectionSurface(cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var headerSubtitle: String {
        let count = viewModel.filteredAndSortedDevices.count

        if count == 0 {
            return String(localized: "popover.waiting")
        }

        return String(format: String(localized: "popover.devices_online"), count)
    }

    private var contentAlignment: Alignment {
        if viewModel.isLoading || viewModel.groupedDevices.isEmpty {
            return .center
        }
        return .top
    }

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary)

            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .batteryToolbarChip(
                    tint: Color.white.opacity(0.66),
                    foreground: Color.secondary
                )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    let macBatteryService = MacBatteryService()
    let viewModel = DeviceListViewModel(deviceManager: macBatteryService)

    return MenuBarPopoverView(viewModel: viewModel)
}
