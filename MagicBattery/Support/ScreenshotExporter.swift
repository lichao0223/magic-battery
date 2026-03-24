import SwiftUI
import AppKit

@MainActor
enum ScreenshotExporter {
    static func exportAll(into directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        MockData.applyScreenshotDefaults()

        let deviceManager = MockDeviceManager()
        let viewModel = DeviceListViewModel(deviceManager: deviceManager)
        deviceManager.startMonitoring()
        viewModel.sortOption = .batteryLevel
        viewModel.sortDirection = .ascending
        viewModel.filterOption = .all

        try render(
            MenuBarPopoverView(viewModel: viewModel),
            size: NSSize(width: 402, height: 642),
            to: directory.appendingPathComponent("01-menubar-popover.png")
        )

        try render(
            MockDeviceDetailsView(device: MockData.detailDevice, snapshot: MockData.detailSnapshot),
            size: NSSize(width: 476, height: 640),
            to: directory.appendingPathComponent("02-device-details.png")
        )

        try render(
            SettingsView(),
            size: NSSize(width: 540, height: 588),
            to: directory.appendingPathComponent("03-settings.png")
        )

        try render(
            MockWidgetShowcaseView(devices: MockData.widgetDevices),
            size: NSSize(width: 760, height: 370),
            to: directory.appendingPathComponent("04-widget.png")
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
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    ForEach(snapshot.sections) { section in
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
            }
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
            Text("Mock 数据预览")
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
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    MockDeviceDetailItemRow(item: item)

                    if index != section.items.count - 1 {
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
            }
        }
        .padding(.vertical, 6)
    }
}

private struct MockWidgetShowcaseView: View {
    let devices: [Device]

    var body: some View {
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

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MagicBattery Widget")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Mock 数据预览")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }

                HStack(spacing: 14) {
                    ForEach(devices.prefix(4)) { device in
                        widgetTile(device: device)
                    }
                }
            }
            .padding(24)
        }
    }

    private func widgetTile(device: Device) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(device.batteryLevel) / 100)
                    .stroke(
                        device.batteryColor,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .padding(18)
                Image(systemName: device.icon.symbolName)
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(.white.opacity(0.92))
                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(x: 24, y: -24)
                }
            }
            .frame(width: 110, height: 110)

            Text(device.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
            Text("\(device.batteryLevel)%")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
    }
}
