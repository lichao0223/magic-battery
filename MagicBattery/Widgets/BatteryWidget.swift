import WidgetKit
import SwiftUI
import OSLog

private let widgetLogger = Logger(subsystem: "com.lc.battery", category: "BatteryWidget")
private let legacyWidgetAppGroupIdentifier = "group.com.lc.battery"

private func widgetAppGroupIdentifier() -> String {
    if let configuredValue = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String {
        let trimmedValue = configuredValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedValue.isEmpty {
            return trimmedValue
        }
    }

    return legacyWidgetAppGroupIdentifier
}

/// 电池小组件
struct BatteryWidget: Widget {
    let kind: String = "BatteryWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BatteryWidgetProvider()) { entry in
            BatteryWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MagicBattery")
        .description(String(localized: "widget.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable()
    }
}

/// 小组件时间线提供者
struct BatteryWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BatteryWidgetEntry {
        widgetLogger.info("placeholder requested, isPreview: \(context.isPreview)")
        return BatteryWidgetEntry(date: Date(), devices: sampleDevices())
    }

    func getSnapshot(in context: Context, completion: @escaping (BatteryWidgetEntry) -> Void) {
        widgetLogger.info("snapshot requested, isPreview: \(context.isPreview)")
        let entry = BatteryWidgetEntry(date: Date(), devices: sampleDevices())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryWidgetEntry>) -> Void) {
        Task {
            let devices = await fetchDevices()
            let currentDate = Date()
            let entry = BatteryWidgetEntry(date: currentDate, devices: devices)

            // 每5分钟更新一次
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: currentDate)!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

            widgetLogger.info("timeline generated with \(devices.count) devices")
            completion(timeline)
        }
    }

    // MARK: - Private Methods

    private func fetchDevices() async -> [Device] {
        // 从共享容器或 UserDefaults 获取设备数据
        // 这里使用 App Group 来共享数据
        if let sharedDefaults = UserDefaults(suiteName: widgetAppGroupIdentifier()),
           let data = sharedDefaults.data(forKey: "devices") {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let devices = try decoder.decode([Device].self, from: data)
                widgetLogger.info("loaded \(devices.count) devices from app group")
                return devices
            } catch {
                widgetLogger.error("failed to decode devices: \(error.localizedDescription)")
            }
        }

        widgetLogger.info("no shared devices found, using empty state")
        return []
    }

    private func sampleDevices() -> [Device] {
        return [
            Device(id: UUID(), name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, lastUpdated: Date()),
            Device(id: UUID(), name: "Magic Mouse", type: .bluetoothMouse, batteryLevel: 45, isCharging: false, lastUpdated: Date()),
            Device(id: UUID(), name: "AirPods", type: .airPods, batteryLevel: 20, isCharging: false, lastUpdated: Date())
        ]
    }
}

/// 小组件时间线条目
struct BatteryWidgetEntry: TimelineEntry {
    let date: Date
    let devices: [Device]
}

/// 小组件视图
struct BatteryWidgetEntryView: View {
    var entry: BatteryWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsWidgetContainerBackground

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(devices: entry.devices)
            case .systemMedium:
                MediumWidgetView(devices: entry.devices)
            case .systemLarge:
                LargeWidgetView(devices: entry.devices)
            default:
                SmallWidgetView(devices: entry.devices)
            }
        }
        .background {
            WidgetReadableBackdrop(renderingMode: widgetRenderingMode)
                .padding(6)
        }
        .containerBackground(for: .widget) {
            WidgetChromeBackground(
                showsBackground: showsWidgetContainerBackground,
                renderingMode: widgetRenderingMode
            )
        }
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let devices: [Device]

    var body: some View {
        WidgetRingGrid(
            devices: Array(devices.prefix(4)),
            style: .small
        )
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let devices: [Device]

    var body: some View {
        WidgetRingStrip(
            devices: Array(devices.prefix(4)),
            style: .medium
        )
    }
}

// MARK: - Large Widget View

struct LargeWidgetView: View {
    let devices: [Device]

    var body: some View {
        LargeWidgetList(
            devices: Array(devices.prefix(4)),
            style: .large
        )
    }
}

private struct WidgetRingGrid: View {
    let devices: [Device]
    let style: WidgetRingGridStyle

    var body: some View {
        GeometryReader { proxy in
            let tileSize = style.tileSize(in: proxy.size)

            VStack(spacing: style.gridSpacing) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: style.gridSpacing) {
                        ForEach(0..<2, id: \.self) { column in
                            let index = row * 2 + column
                            WidgetRingTile(
                                device: index < devices.count ? devices[index] : nil,
                                style: style
                            )
                            .padding(style.tileInset)
                            .frame(width: tileSize, height: tileSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: style.alignment)
            .padding(style.contentPadding)
        }
    }
}

private struct WidgetRingStrip: View {
    let devices: [Device]
    let style: WidgetRingGridStyle

    var body: some View {
        GeometryReader { proxy in
            let tileWidth = style.stripTileWidth(in: proxy.size)
            let ringDiameter = style.stripRingDiameter(
                in: proxy.size,
                tileWidth: tileWidth
            )

            HStack(spacing: style.stripSpacing) {
                ForEach(0..<4, id: \.self) { index in
                    WidgetStripTile(
                        device: index < devices.count ? devices[index] : nil,
                        style: style,
                        ringDiameter: ringDiameter
                    )
                    .frame(width: tileWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(style.contentPadding)
        }
    }
}

private struct LargeWidgetList: View {
    let devices: [Device]
    let style: WidgetListStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.rowSpacing) {
            ForEach(Array(devices.enumerated()), id: \.element.id) { index, device in
                LargeWidgetListRow(device: device, style: style)

                if index < devices.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 1)
                        .padding(.leading, style.separatorInset)
                }
            }

            if devices.count < 4 {
                ForEach(0..<(4 - devices.count), id: \.self) { _ in
                    LargeWidgetPlaceholderRow(style: style)
                }
            }
        }
        .padding(style.contentPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct WidgetRingTile: View {
    let device: Device?
    let style: WidgetRingGridStyle

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(device == nil ? 0.03 : 0.07))

            Circle()
                .stroke(Color.white.opacity(device == nil ? 0.10 : 0.12), lineWidth: style.ringLineWidth)

            if let device {
                Circle()
                    .trim(from: 0, to: ringProgress(for: device))
                    .stroke(
                        ringColor(for: device),
                        style: StrokeStyle(lineWidth: style.ringLineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: ringColor(for: device).opacity(0.18), radius: 8)
                    .widgetAccentable()

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .padding(style.innerInset)

                Image(systemName: device.icon.symbolName)
                    .font(.system(size: style.iconSize, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.90))

                if device.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: style.boltSize, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .offset(x: style.boltOffset.width, y: style.boltOffset.height)
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.025))
                    .padding(style.innerInset)
            }
        }
    }

    private func ringProgress(for device: Device) -> CGFloat {
        if device.batteryLevel < 0 {
            return 0.06
        }

        return max(0.06, min(CGFloat(device.batteryLevel) / 100, 1))
    }

    private func ringColor(for device: Device) -> Color {
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
}

private struct WidgetStripTile: View {
    let device: Device?
    let style: WidgetRingGridStyle
    let ringDiameter: CGFloat

    var body: some View {
        VStack(spacing: style.stripLabelSpacing) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(device == nil ? 0.03 : 0.07))

                Circle()
                    .stroke(Color.white.opacity(device == nil ? 0.10 : 0.12), lineWidth: style.ringLineWidth)

                if let device {
                    Circle()
                        .trim(from: 0, to: ringProgress(for: device))
                        .stroke(
                            Color.white.opacity(0.92),
                            style: StrokeStyle(lineWidth: style.ringLineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .widgetAccentable()

                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .padding(style.innerInset)

                    Image(systemName: device.icon.symbolName)
                        .font(.system(size: style.iconSize, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.90))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.025))
                        .padding(style.innerInset)
                }
            }
            .frame(width: ringDiameter, height: ringDiameter)

            Text(labelText)
                .font(.system(size: style.stripLabelSize, weight: .medium))
                .foregroundStyle(Color.white.opacity(device == nil ? 0.0 : 0.90))
        }
    }

    private var labelText: String {
        guard let device else { return " " }
        if device.batteryLevel < 0 { return "--" }
        return "\(device.batteryLevel)%"
    }

    private func ringProgress(for device: Device) -> CGFloat {
        if device.batteryLevel < 0 {
            return 0.06
        }

        return max(0.06, min(CGFloat(device.batteryLevel) / 100, 1))
    }
}

private struct LargeWidgetListRow: View {
    let device: Device
    let style: WidgetListStyle

    var body: some View {
        HStack(spacing: style.contentSpacing) {
            Image(systemName: device.icon.symbolName)
                .font(.system(size: style.iconSize, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.84))
                .frame(width: style.iconFrameWidth, alignment: .leading)

            Text(device.name)
                .font(.system(size: style.nameFontSize, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.90))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: style.metricSpacing) {
                Text(deviceLabelText)
                    .font(.system(size: style.valueFontSize, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .monospacedDigit()

                Image(systemName: batterySymbolName)
                    .font(.system(size: style.batteryIconSize, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
            }
        }
        .padding(.horizontal, style.rowHorizontalPadding)
        .padding(.vertical, style.rowVerticalPadding)
    }

    private var deviceLabelText: String {
        if device.batteryLevel < 0 {
            return "--"
        }
        return "\(device.batteryLevel)%"
    }

    private var batterySymbolName: String {
        if device.isCharging {
            return "battery.100.bolt"
        }
        if device.batteryLevel < 0 {
            return "battery.0"
        }
        if device.batteryLevel <= 10 {
            return "battery.0"
        }
        if device.batteryLevel <= 30 {
            return "battery.25"
        }
        if device.batteryLevel <= 60 {
            return "battery.50"
        }
        if device.batteryLevel <= 85 {
            return "battery.75"
        }
        return "battery.100"
    }
}

private struct LargeWidgetPlaceholderRow: View {
    let style: WidgetListStyle

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(height: 1)
            .padding(.leading, style.separatorInset)
    }
}

private struct WidgetChromeBackground: View {
    let showsBackground: Bool
    let renderingMode: WidgetRenderingMode

    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    var body: some View {
        Group {
            if shouldLetSystemOwnBackground {
                Color.clear
            } else {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.58, green: 0.65, blue: 0.82).opacity(0.28),
                                Color(red: 0.41, green: 0.48, blue: 0.64).opacity(0.22),
                                Color(red: 0.24, green: 0.29, blue: 0.41).opacity(0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.white.opacity(0.03),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        shape
                            .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                    }
            }
        }
    }

    private var shouldLetSystemOwnBackground: Bool {
        if !showsBackground {
            return true
        }

        switch renderingMode {
        case .accented:
            return true
        default:
            return false
        }
    }
}

private struct WidgetReadableBackdrop: View {
    let renderingMode: WidgetRenderingMode

    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        shape
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.03),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 90)
                    .clipShape(shape)
            }
            .overlay {
                shape
                    .strokeBorder(Color.white.opacity(borderOpacity), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }

    private var gradientColors: [Color] {
        switch renderingMode {
        case .accented:
            return [
                Color(red: 0.40, green: 0.49, blue: 0.66).opacity(0.58),
                Color(red: 0.29, green: 0.36, blue: 0.50).opacity(0.52),
                Color(red: 0.17, green: 0.22, blue: 0.33).opacity(0.62)
            ]
        default:
            return [
                Color(red: 0.43, green: 0.52, blue: 0.69).opacity(0.46),
                Color(red: 0.31, green: 0.38, blue: 0.53).opacity(0.40),
                Color(red: 0.18, green: 0.23, blue: 0.34).opacity(0.50)
            ]
        }
    }

    private var borderOpacity: CGFloat {
        switch renderingMode {
        case .accented:
            return 0.22
        default:
            return 0.18
        }
    }
}

private enum WidgetRingGridStyle {
    case small
    case medium
    case large

    var contentPadding: CGFloat {
        switch self {
        case .small:
            return 14
        case .medium:
            return 18
        case .large:
            return 20
        }
    }

    var gridSpacing: CGFloat {
        switch self {
        case .small:
            return 16
        case .medium:
            return 18
        case .large:
            return 18
        }
    }

    var ringLineWidth: CGFloat {
        switch self {
        case .small:
            return 9
        case .medium:
            return 10
        case .large:
            return 14
        }
    }

    var innerInset: CGFloat {
        switch self {
        case .small:
            return 18
        case .medium:
            return 14
        case .large:
            return 20
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small:
            return 26
        case .medium:
            return 28
        case .large:
            return 42
        }
    }

    var boltSize: CGFloat {
        switch self {
        case .small:
            return 10
        case .medium:
            return 11
        case .large:
            return 15
        }
    }

    var boltOffset: CGSize {
        switch self {
        case .small:
            return CGSize(width: 17, height: 18)
        case .medium:
            return CGSize(width: 17, height: 18)
        case .large:
            return CGSize(width: 26, height: 28)
        }
    }

    var alignment: Alignment {
        .center
    }

    func tileSize(in size: CGSize) -> CGFloat {
        let availableWidth = size.width - (contentPadding * 2) - gridSpacing
        let availableHeight = size.height - (contentPadding * 2) - gridSpacing
        return min(availableWidth / 2, availableHeight / 2)
    }

    var tileInset: CGFloat {
        switch self {
        case .small:
            return 2
        case .medium:
            return 0
        case .large:
            return 0
        }
    }

    var stripSpacing: CGFloat {
        switch self {
        case .small:
            return 8
        case .medium:
            return 18
        case .large:
            return 14
        }
    }

    var stripMaxRingDiameter: CGFloat {
        switch self {
        case .small:
            return 68
        case .medium:
            return 64
        case .large:
            return 98
        }
    }

    var stripLabelSpacing: CGFloat {
        switch self {
        case .small:
            return 10
        case .medium:
            return 10
        case .large:
            return 14
        }
    }

    var stripLabelSize: CGFloat {
        switch self {
        case .small:
            return 14
        case .medium:
            return 14
        case .large:
            return 20
        }
    }

    func stripTileWidth(in size: CGSize) -> CGFloat {
        let availableWidth = size.width - (contentPadding * 2) - (stripSpacing * 3)
        return availableWidth / 4
    }

    func stripRingDiameter(in size: CGSize, tileWidth: CGFloat) -> CGFloat {
        let verticalAllowance = max(size.height - (contentPadding * 2) - stripLabelSize - stripLabelSpacing, 36)
        return min(stripMaxRingDiameter, tileWidth - 4, verticalAllowance)
    }
}

private enum WidgetListStyle {
    case large

    var contentPadding: CGFloat {
        18
    }

    var rowSpacing: CGFloat {
        8
    }

    var contentSpacing: CGFloat {
        8
    }

    var iconSize: CGFloat {
        17
    }

    var iconFrameWidth: CGFloat {
        22
    }

    var nameFontSize: CGFloat {
        14
    }

    var valueFontSize: CGFloat {
        12
    }

    var rowHorizontalPadding: CGFloat {
        12
    }

    var rowVerticalPadding: CGFloat {
        10
    }

    var metricSpacing: CGFloat {
        6
    }

    var batteryIconSize: CGFloat {
        13
    }

    var separatorInset: CGFloat {
        26
    }
}

private enum WidgetLayoutStyle {
    case small
    case medium
    case large

    var headerFontSize: CGFloat {
        switch self {
        case .small:
            return 14
        case .medium:
            return 16
        case .large:
            return 17
        }
    }
}

private enum WidgetRingTextStyle {
    case hidden
}

private extension WidgetRingGridStyle {
    var debugName: String {
        switch self {
        case .small:
            return "small"
        case .medium:
            return "medium"
        case .large:
            return "large"
        }
    }
}

// MARK: - Preview

#Preview("Small", as: .systemSmall) {
    BatteryWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, devices: [
        Device(id: UUID(), name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, lastUpdated: Date())
    ])
}

#Preview("Medium", as: .systemMedium) {
    BatteryWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, devices: [
        Device(id: UUID(), name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, lastUpdated: Date()),
        Device(id: UUID(), name: "Magic Keyboard", type: .bluetoothKeyboard, batteryLevel: 45, isCharging: false, lastUpdated: Date()),
        Device(id: UUID(), name: "AirPods", type: .airPods, batteryLevel: 20, isCharging: false, lastUpdated: Date())
    ])
}

#Preview("Large", as: .systemLarge) {
    BatteryWidget()
} timeline: {
    BatteryWidgetEntry(date: .now, devices: [
        Device(id: UUID(), name: "MacBook Pro", type: .mac, batteryLevel: 85, isCharging: true, lastUpdated: Date()),
        Device(id: UUID(), name: "Magic Keyboard", type: .bluetoothKeyboard, batteryLevel: 45, isCharging: false, lastUpdated: Date()),
        Device(id: UUID(), name: "AirPods", type: .airPods, batteryLevel: 20, isCharging: false, lastUpdated: Date()),
        Device(id: UUID(), name: "Magic Mouse", type: .bluetoothMouse, batteryLevel: 60, isCharging: false, lastUpdated: Date())
    ])
}
