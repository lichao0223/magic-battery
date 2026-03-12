import SwiftUI

struct DeviceDetailsSheet: View {
    let device: Device

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: DeviceDetailsViewModel

    init(device: Device) {
        self.device = device
        _viewModel = StateObject(wrappedValue: DeviceDetailsViewModel(device: device))
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
        .padding(10)
        .background(BatteryAtmosphereBackground())
        .batteryPanelSurface(cornerRadius: 30, tint: Color.white.opacity(0.08))
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var panelContent: some View {
        VStack(spacing: 0) {
            headerView

            BatteryHairline()
                .padding(.horizontal, 12)

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            BatteryHairline()
                .padding(.horizontal, 12)

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
                            colors: [
                                Color.white.opacity(0.94),
                                Color(red: 0.92, green: 0.97, blue: 0.99).opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.88), lineWidth: 1)
                    )

                Image(systemName: device.icon.symbolName)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.74))
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.82))
                    .lineLimit(1)

                Text(viewModel.snapshot?.subtitle ?? defaultSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .lineLimit(2)
            }

            Spacer(minLength: 10)

            batteryBadge

            Button {
                Task {
                    await viewModel.reload()
                }
            } label: {
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
            .help(String(localized: "details.refresh_help"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.snapshot == nil {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(0.85)
                Text("details.loading")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.58))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        } else if let snapshot = viewModel.snapshot {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    if let errorMessage = viewModel.errorMessage {
                        inlineNote(text: errorMessage, tone: .orange)
                    }

                    ForEach(snapshot.sections) { section in
                        DeviceDetailSectionCard(section: section)
                    }

                    if let footnote = snapshot.footnote {
                        inlineNote(text: footnote, tone: Color.black.opacity(0.62))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(Color.orange.opacity(0.88))
                Text(viewModel.errorMessage ?? String(localized: "details.unavailable"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.78))
                Text("details.retry_hint")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.black.opacity(0.54))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
        }
    }

    private var footerView: some View {
        HStack {
            if device.isStale {
                Text("details.offline_hint")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.orange.opacity(0.88))
            }

            Spacer()

            Button("common.close") {
                dismiss()
            }
            .batterySecondaryControlStyle(compact: true)
        }
        .padding(8)
        .batterySectionSurface(cornerRadius: 20)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var batteryBadge: some View {
        HStack(spacing: 6) {
            if device.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.84, green: 0.58, blue: 0.08))
            }

            Text(device.isBatteryUnknown ? String(localized: "common.unknown") : "\(device.batteryLevel)%")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(device.batteryColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.78))
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.72), lineWidth: 1)
                )
        )
    }

    private var defaultSubtitle: String {
        let parts = [device.type.displayName, device.sourceLabel].compactMap { $0 }
        return parts.isEmpty ? String(localized: "details.default_subtitle") : parts.joined(separator: " · ")
    }

    private func inlineNote(text: String, tone: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(tone)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .batterySectionSurface(cornerRadius: 16)
    }
}

private struct DeviceDetailSectionCard: View {
    let section: DeviceDetailSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.72))

            VStack(spacing: 0) {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    DeviceDetailItemRow(item: item)

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

private struct DeviceDetailItemRow: View {
    let item: DeviceDetailItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(item.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.56))

                Spacer(minLength: 8)

                Text(item.value)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.80))
                    .multilineTextAlignment(.trailing)
            }

            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.black.opacity(0.46))
            }
        }
        .padding(.vertical, 6)
    }
}
