import SwiftUI

extension View {
    @ViewBuilder
    func batteryPanelSurface(cornerRadius: CGFloat = 28, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(macOS 26.0, *) {
            let glass = tint.map { SwiftUI.Glass.regular.tint($0) } ?? SwiftUI.Glass.regular
            self
                .background {
                    Color.clear
                        .glassEffect(glass, in: shape)
                        .overlay(
                            shape.strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
                }
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(Color.white.opacity(0.20), lineWidth: 0.8)
                )
        }
    }

    func batteryCardSurface(cornerRadius: CGFloat = 18, tint: Color? = nil) -> some View {
        modifier(BatteryCardSurfaceModifier(cornerRadius: cornerRadius, tint: tint))
    }

    func batterySectionSurface(cornerRadius: CGFloat = 22) -> some View {
        modifier(BatterySectionSurfaceModifier(cornerRadius: cornerRadius))
    }

    func batterySecondaryControlStyle(compact: Bool = false) -> some View {
        buttonStyle(BatteryControlButtonStyle(tone: .secondary, compact: compact))
    }

    func batteryProminentControlStyle(compact: Bool = false) -> some View {
        buttonStyle(BatteryControlButtonStyle(tone: .prominent, compact: compact))
    }

    func batteryDestructiveControlStyle(compact: Bool = false) -> some View {
        buttonStyle(BatteryControlButtonStyle(tone: .destructive, compact: compact))
    }

    func batteryToolbarChip(
        tint: Color = Color.white.opacity(0.76),
        foreground: Color = Color.primary.opacity(0.85)
    ) -> some View {
        modifier(BatteryToolbarChipModifier(tint: tint, foreground: foreground))
    }
}

// MARK: - BatteryCardSurfaceModifier

private struct BatteryCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark

        if #available(macOS 26.0, *) {
            content
                .background {
                    shape
                        .fill(
                            LinearGradient(
                                colors: isDark
                                    ? [
                                        Color.white.opacity(0.08),
                                        Color.white.opacity(0.05)
                                    ]
                                    : [
                                        Color.white.opacity(0.97),
                                        Color(red: 0.94, green: 0.97, blue: 0.99).opacity(0.90)
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            shape.stroke(
                                Color.white.opacity(isDark ? 0.12 : 0.88),
                                lineWidth: 1
                            )
                        )
                        .shadow(
                            color: isDark ? .clear : .black.opacity(0.08),
                            radius: 12, y: 6
                        )
                }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(
                    shape.stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )
        }
    }
}

// MARK: - BatterySectionSurfaceModifier

private struct BatterySectionSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let isDark = colorScheme == .dark

        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: isDark
                                ? [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.06)
                                ]
                                : [
                                    Color.white.opacity(0.76),
                                    Color.white.opacity(0.58)
                                ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        shape.stroke(
                            Color.white.opacity(isDark ? 0.10 : 0.64),
                            lineWidth: 1
                        )
                    )
                    .shadow(
                        color: isDark ? .clear : .black.opacity(0.05),
                        radius: 10, y: 5
                    )
            }
    }
}

// MARK: - BatteryAtmosphereBackground

struct BatteryAtmosphereBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark

        ZStack {
            LinearGradient(
                colors: isDark
                    ? [
                        Color(red: 0.08, green: 0.10, blue: 0.16),
                        Color(red: 0.10, green: 0.14, blue: 0.18),
                        Color(red: 0.08, green: 0.12, blue: 0.15)
                    ]
                    : [
                        Color(red: 0.80, green: 0.88, blue: 0.97),
                        Color(red: 0.90, green: 0.95, blue: 0.88),
                        Color(red: 0.83, green: 0.91, blue: 0.94)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.white.opacity(isDark ? 0.04 : 0.55))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: -90, y: -120)

            Circle()
                .fill(Color.cyan.opacity(isDark ? 0.08 : 0.22))
                .frame(width: 180, height: 180)
                .blur(radius: 30)
                .offset(x: 110, y: 120)

            Circle()
                .fill(Color.mint.opacity(isDark ? 0.06 : 0.18))
                .frame(width: 140, height: 140)
                .blur(radius: 24)
                .offset(x: 100, y: -90)
        }
    }
}

// MARK: - BatteryHairline

struct BatteryHairline: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let isDark = colorScheme == .dark

        LinearGradient(
            colors: [
                Color.white.opacity(0),
                Color.white.opacity(isDark ? 0.16 : 0.72),
                Color.white.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
        .opacity(isDark ? 0.50 : 0.72)
    }
}

// MARK: - MagicBatteryMark

struct MagicBatteryMark: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.20, green: 0.76, blue: 0.93),
                            Color(red: 0.09, green: 0.49, blue: 0.76)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .stroke(Color.white.opacity(0.44), lineWidth: 1)

            Image(systemName: "battery.100.bolt")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
    }
}

// MARK: - BatteryControlButtonStyle

private enum BatteryControlTone {
    case secondary
    case prominent
    case destructive
}

private struct BatteryControlButtonStyle: ButtonStyle {
    let tone: BatteryControlTone
    let compact: Bool
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        let metrics = compact ? Metrics.compact : Metrics.regular

        configuration.label
            .font(.system(size: metrics.fontSize, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, metrics.verticalPadding)
            .background {
                Capsule(style: .continuous)
                    .fill(background(configuration.isPressed))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(borderColor.opacity(configuration.isPressed ? 0.92 : 1), lineWidth: 1)
                    )
                    .shadow(color: shadowColor.opacity(configuration.isPressed ? 0.05 : 1), radius: 10, y: 5)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        let isDark = colorScheme == .dark
        switch tone {
        case .secondary:
            return isDark ? Color.white.opacity(0.82) : Color.black.opacity(0.78)
        case .prominent:
            return .white
        case .destructive:
            return isDark
                ? Color(red: 0.96, green: 0.42, blue: 0.40)
                : Color(red: 0.58, green: 0.15, blue: 0.14)
        }
    }

    private var borderColor: Color {
        let isDark = colorScheme == .dark
        switch tone {
        case .secondary:
            return isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.72)
        case .prominent:
            return Color.white.opacity(0.24)
        case .destructive:
            return isDark ? Color.white.opacity(0.12) : Color.white.opacity(0.70)
        }
    }

    private var shadowColor: Color {
        let isDark = colorScheme == .dark
        if isDark { return .clear }
        switch tone {
        case .secondary:
            return .black.opacity(0.08)
        case .prominent:
            return Color(red: 0.05, green: 0.25, blue: 0.32).opacity(0.24)
        case .destructive:
            return Color.red.opacity(0.10)
        }
    }

    private func background(_ isPressed: Bool) -> LinearGradient {
        let isDark = colorScheme == .dark
        switch tone {
        case .secondary:
            return LinearGradient(
                colors: isDark
                    ? [
                        Color.white.opacity(isPressed ? 0.10 : 0.14),
                        Color.white.opacity(isPressed ? 0.06 : 0.10)
                    ]
                    : [
                        Color.white.opacity(isPressed ? 0.70 : 0.82),
                        Color.white.opacity(isPressed ? 0.56 : 0.68)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .prominent:
            return LinearGradient(
                colors: [
                    Color(red: 0.20, green: 0.72, blue: 0.92).opacity(isPressed ? 0.84 : 0.96),
                    Color(red: 0.09, green: 0.46, blue: 0.74).opacity(isPressed ? 0.88 : 1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .destructive:
            return LinearGradient(
                colors: isDark
                    ? [
                        Color.red.opacity(isPressed ? 0.20 : 0.14),
                        Color.red.opacity(isPressed ? 0.14 : 0.10)
                    ]
                    : [
                        Color.white.opacity(isPressed ? 0.72 : 0.82),
                        Color(red: 1, green: 0.95, blue: 0.95).opacity(isPressed ? 0.62 : 0.76)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private struct Metrics {
        let fontSize: CGFloat
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat

        static let regular = Metrics(fontSize: 12, horizontalPadding: 12, verticalPadding: 8)
        static let compact = Metrics(fontSize: 11, horizontalPadding: 9, verticalPadding: 7)
    }
}

// MARK: - BatteryToolbarChipModifier

private struct BatteryToolbarChipModifier: ViewModifier {
    let tint: Color
    let foreground: Color
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let isDark = colorScheme == .dark

        content
            .foregroundStyle(foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint,
                                tint.opacity(0.84)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                Color.white.opacity(isDark ? 0.12 : 0.68),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isDark ? .clear : .black.opacity(0.05),
                        radius: 8, y: 4
                    )
            }
    }
}
