import SwiftUI
import AppKit

@MainActor
enum ScreenshotExporter {
    static func exportAll(into directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        MockData.applyScreenshotDefaults()

        try render(
            MockMenuBarPopoverScreenshotView(devices: MockData.devices),
            size: NSSize(width: 402, height: 642),
            to: directory.appendingPathComponent("01-menubar-popover.png")
        )

        try render(
            MockDeviceDetailsView(device: MockData.detailDevice, snapshot: MockData.detailSnapshot),
            size: NSSize(width: 476, height: 640),
            to: directory.appendingPathComponent("02-device-details.png")
        )

        try render(
            MockSettingsScreenshotView(),
            size: NSSize(width: 540, height: 588),
            to: directory.appendingPathComponent("03-settings.png")
        )

        try render(
            MockWidgetSmallScreenshotView(devices: MockData.widgetDevices),
            size: NSSize(width: 338, height: 338),
            to: directory.appendingPathComponent("04-widget-small.png")
        )

        try render(
            MockWidgetMediumScreenshotView(devices: MockData.widgetDevices),
            size: NSSize(width: 720, height: 338),
            to: directory.appendingPathComponent("05-widget-medium.png")
        )

        try render(
            MockWidgetLargeScreenshotView(devices: MockData.widgetDevices),
            size: NSSize(width: 720, height: 720),
            to: directory.appendingPathComponent("06-widget-large.png")
        )
    }

    private static func render<V: View>(_ view: V, size: NSSize, to url: URL) throws {
        let hosted = view
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: hosted)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.isOpaque = false

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ScreenshotExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render screenshot for \(url.lastPathComponent)"])
        }

        try png.write(to: url)
    }
}

private struct MockMenuBarPopoverScreenshotView: View {
    let devices: [Device]
    @AppStorage("appearanceMode") private var appearanceMode = 2

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var menuDevices: [Device] {
        Array(devices.prefix(6))
    }

    private var lowBatteryCount: Int {
        menuDevices.filter { $0.isLowBattery(threshold: 20) && !$0.isCharging }.count
    }

    private var sections: [(title: String, devices: [Device])] {
        [
            ("这台 Mac", menuDevices.filter { $0.type == .mac }),
            ("Apple 设备", menuDevices.filter { [.iPhone, .iPad, .appleWatch].contains($0.type) }),
            ("配件", menuDevices.filter { ![.mac, .iPhone, .iPad, .appleWatch].contains($0.type) })
        ].filter { !$0.devices.isEmpty }
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
        .preferredColorScheme(resolvedColorScheme)
        .padding(10)
        .background(BatteryAtmosphereBackground())
        .batteryPanelSurface(cornerRadius: 30, tint: Color.white.opacity(0.08))
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            headerView
            BatteryHairline().padding(.horizontal, 12)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(section.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                            Text("\(section.devices.count)")
                                .font(.system(size: 10, weight: .semibold))
                                .batteryToolbarChip(
                                    tint: Color.white.opacity(0.66),
                                    foreground: Color.secondary
                                )
                        }
                        .padding(.horizontal, 4)

                        ForEach(section.devices) { device in
                            DeviceRowView(device: device, onTap: device.supportsBatteryDetails ? {} : nil)
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BatteryHairline().padding(.horizontal, 12)
            footerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            MagicBatteryMark(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("MagicBattery")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("6 台设备在线 · Mock 数据")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer(minLength: 10)

            if lowBatteryCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                    Text("低电量 \(lowBatteryCount)")
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
                .batteryToolbarChip(
                    tint: Color.orange.opacity(0.18),
                    foreground: Color(red: 0.72, green: 0.34, blue: 0.04)
                )
            }

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 30, height: 30)
                .batterySecondaryControlStyle(compact: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var footerView: some View {
        HStack {
            footerChip(symbol: "battery.75", title: "按电量")
            footerChip(symbol: "arrow.up", title: "升序")
            Spacer()
            footerChip(symbol: "gearshape", title: "设置")
            footerDestructiveChip(symbol: "power", title: "退出")
        }
        .padding(8)
        .batterySectionSurface(cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func footerChip(symbol: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.clear)
        .batterySecondaryControlStyle(compact: true)
    }

    private func footerDestructiveChip(symbol: String, title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 11))
            Text(title)
                .font(.system(size: 11))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.clear)
        .batteryDestructiveControlStyle(compact: true)
    }
}

private struct MockDeviceDetailsView: View {
    let device: Device
    let snapshot: DeviceDetailSnapshot
    @AppStorage("appearanceMode") private var appearanceMode = 2

    private var resolvedColorScheme: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var visibleSections: [DeviceDetailSection] {
        Array(snapshot.sections.prefix(3))
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
        .frame(width: 456, height: 620, alignment: .top)
        .preferredColorScheme(resolvedColorScheme)
        .padding(10)
        .background(BatteryAtmosphereBackground())
        .batteryPanelSurface(cornerRadius: 30, tint: Color.white.opacity(0.08))
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            headerView
            BatteryHairline().padding(.horizontal, 12)

            VStack(spacing: 12) {
                ForEach(visibleSections) { section in
                    MockDeviceDetailSectionCard(section: section)
                }

                if let footnote = snapshot.footnote {
                    Text(footnote)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .batterySectionSurface(cornerRadius: 16)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BatteryHairline().padding(.horizontal, 12)
            footerView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Image(systemName: device.icon.symbolName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.85))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Text(snapshot.subtitle ?? "Mock Details")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            HStack(spacing: 6) {
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(red: 0.84, green: 0.58, blue: 0.08))
                }

                Text("\(device.batteryLevel)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(device.batteryColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var footerView: some View {
        HStack {
            Text("设备详情 · Mock 数据")
                .font(.system(size: 10.5))
                .foregroundStyle(Color.secondary)

            Spacer()

            Text("README Screenshot")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .batterySecondaryControlStyle(compact: true)
        }
        .padding(8)
        .batterySectionSurface(cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

private struct MockDeviceDetailSectionCard: View {
    let section: DeviceDetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondary)

            VStack(spacing: 0) {
                ForEach(Array(section.items.prefix(4).enumerated()), id: \.element.id) { index, item in
                    MockDeviceDetailItemRow(item: item)

                    if index != min(section.items.count, 4) - 1 {
                        BatteryHairline()
                            .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .batteryCardSurface(cornerRadius: 22, tint: Color.white.opacity(0.04))
    }
}

private struct MockDeviceDetailItemRow: View {
    let item: DeviceDetailItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.secondary)

                Spacer(minLength: 8)

                Text(item.value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.trailing)
            }

            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.secondary.opacity(0.7))
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MockSettingsScreenshotView: View {
    @AppStorage("appearanceMode") private var appearanceMode = 2

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
            BatteryHairline().padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 14) {
                MockSettingSectionCard(title: "通知", subtitle: "低电量提醒与测试通知") {
                    MockToggleRow(title: "启用低电量通知", isOn: true)
                    MockSliderRow(title: "提醒阈值", valueText: "20%")
                    MockButtonRow(title: "发送测试通知", symbol: "bell.badge")
                }

                MockSettingSectionCard(title: "刷新", subtitle: "主应用与蓝牙扫描频率") {
                    MockSliderRow(title: "设备刷新间隔", valueText: "60 秒")
                    MockSliderRow(title: "蓝牙扫描间隔", valueText: "120 秒")
                }

                HStack(alignment: .top, spacing: 14) {
                    MockSettingSectionCard(title: "Apple 设备", subtitle: "iPhone / iPad / Watch") {
                        MockToggleRow(title: "启用 iPhone / iPad 发现", isOn: true)
                        MockToggleRow(title: "启用 Apple Watch 电量同步", isOn: true)
                        MockToggleRow(title: "显示离线设备", isOn: true)
                    }

                    MockSettingSectionCard(title: "外观与启动", subtitle: "界面与开机行为") {
                        MockToggleRow(title: "在 Dock 中显示", isOn: false)
                        MockToggleRow(title: "登录时启动", isOn: true)
                        MockSegmentedRow(title: "外观", options: ["跟随系统", "浅色", "深色"], selectedIndex: 2)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BatteryHairline().padding(.horizontal, 16)
            footerView
        }
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            MagicBatteryMark(size: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)

                Text("常用配置 · Mock 数据预览")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 30, height: 30)
                .batterySecondaryControlStyle(compact: true)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var footerView: some View {
        HStack {
            Label("恢复默认", systemImage: "arrow.counterclockwise")
                .batterySecondaryControlStyle()

            Spacer()

            Label("完成", systemImage: "checkmark")
                .batteryProminentControlStyle()
        }
        .padding(12)
        .batterySectionSurface(cornerRadius: 22)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct MockSettingSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondary)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .batteryCardSurface(cornerRadius: 22, tint: Color.white.opacity(0.04))
    }
}

private struct MockToggleRow: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.88))
            Spacer(minLength: 8)
            Capsule()
                .fill(isOn ? Color.cyan.opacity(0.86) : Color.white.opacity(0.16))
                .frame(width: 38, height: 22)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .padding(3)
                }
        }
    }
}

private struct MockSliderRow: View {
    let title: String
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primary.opacity(0.88))
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold))
                    .batteryToolbarChip(
                        tint: Color.cyan.opacity(0.14),
                        foreground: Color.primary.opacity(0.85)
                    )
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.cyan.opacity(0.85))
                    .frame(width: 116, height: 6)
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .offset(x: 108)
            }
        }
    }
}

private struct MockSegmentedRow: View {
    let title: String
    let options: [String]
    let selectedIndex: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.primary.opacity(0.88))

            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Text(option)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(index == selectedIndex ? Color.primary : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule(style: .continuous)
                                .fill(index == selectedIndex ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                        )
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
        }
    }
}

private struct MockButtonRow: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .batterySecondaryControlStyle()
    }
}

private struct MockWidgetSmallScreenshotView: View {
    let devices: [Device]

    var body: some View {
        widgetChrome {
            let visible = Array(devices.prefix(4))
            VStack(spacing: 10) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            MockWidgetRingTile(device: index < visible.count ? visible[index] : nil, diameter: 110, iconSize: 26, lineWidth: 10)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(22)
        }
    }
}

private struct MockWidgetMediumScreenshotView: View {
    let devices: [Device]

    var body: some View {
        widgetChrome {
            HStack(spacing: 20) {
                ForEach(Array(devices.prefix(4).enumerated()), id: \.element.id) { _, device in
                    VStack(spacing: 12) {
                        MockWidgetRingTile(device: device, diameter: 112, iconSize: 24, lineWidth: 10)
                        Text(device.batteryLevel < 0 ? "--" : "\(device.batteryLevel)%")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
        }
    }
}

private struct MockWidgetLargeScreenshotView: View {
    let devices: [Device]

    var body: some View {
        widgetChrome {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MagicBattery")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Large Widget · Mock 数据")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }

                VStack(spacing: 0) {
                    ForEach(Array(devices.prefix(4).enumerated()), id: \.element.id) { index, device in
                        HStack(spacing: 14) {
                            Image(systemName: device.icon.symbolName)
                                .font(.system(size: 22, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.84))
                                .frame(width: 28, alignment: .leading)

                            Text(device.name)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.92))
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Text(device.batteryLevel < 0 ? "--" : "\(device.batteryLevel)%")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(widgetRingColor(for: device))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)

                        if index < min(devices.count, 4) - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 1)
                                .padding(.leading, 12)
                        }
                    }
                }
                .padding(10)
                .batteryCardSurface(cornerRadius: 24, tint: Color.white.opacity(0.04))
            }
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

private func widgetChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.13, blue: 0.21),
                        Color(red: 0.08, green: 0.15, blue: 0.18),
                        Color(red: 0.09, green: 0.11, blue: 0.16)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

        content()
    }
}

private struct MockWidgetRingTile: View {
    let device: Device?
    let diameter: CGFloat
    let iconSize: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(device == nil ? 0.03 : 0.07))

            Circle()
                .stroke(Color.white.opacity(device == nil ? 0.10 : 0.12), lineWidth: lineWidth)

            if let device {
                Circle()
                    .trim(from: 0, to: ringProgress(for: device))
                    .stroke(
                        widgetRingColor(for: device),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .padding(diameter * 0.17)

                Image(systemName: device.icon.symbolName)
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.92))

                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: iconSize * 0.44, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .offset(x: diameter * 0.21, y: diameter * -0.21)
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

private func ringProgress(for device: Device) -> CGFloat {
    if device.batteryLevel < 0 { return 0.06 }
    return max(0.06, min(CGFloat(device.batteryLevel) / 100, 1))
}

private func widgetRingColor(for device: Device) -> Color {
    if device.batteryLevel < 0 {
        return Color.white.opacity(0.22)
    }
    if device.batteryLevel <= 20 {
        return Color(red: 1.0, green: 0.38, blue: 0.35)
    } else if device.batteryLevel <= 30 {
        return Color(red: 1.0, green: 0.73, blue: 0.31)
    } else {
        return Color(red: 0.42, green: 0.86, blue: 0.34)
    }
}
