import SwiftUI

// MARK: - Color System

extension Color {
    /// Adaptive brand teal: deep emerald-teal in light mode, vibrant cyan-mint in dark mode.
    static let teal = Color("AccentColor")

    /// Clinical Severity Core Colors
    static func severityColor(_ s: Severity) -> Color {
        switch s {
        case .unstable: Color(red: 0.92, green: 0.26, blue: 0.22) // Vibrant Crimson Red
        case .watch:    Color(red: 0.95, green: 0.55, blue: 0.10) // Warm Amber Orange
        case .stable:   Color(red: 0.08, green: 0.68, blue: 0.44) // Crisp Medical Emerald
        }
    }

    /// High-contrast Foreground Text & Icon Color
    static func severityFG(_ s: Severity) -> Color {
        severityColor(s)
    }

    /// Subtle Translucent Tint Background for Pills & Badges
    static func severityBG(_ s: Severity) -> Color {
        severityColor(s).opacity(0.14)
    }

    /// Subtle Border for Pills & Cards
    static func severityBorder(_ s: Severity) -> Color {
        severityColor(s).opacity(0.32)
    }
}

// MARK: - Typography & Fonts

struct AppFont {
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func title(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}

// MARK: - Card Surface Styling

struct CardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(scheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        scheme == .dark
                            ? Color.white.opacity(0.08)
                            : Color.black.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: scheme == .dark
                    ? Color.clear
                    : Color.black.opacity(0.04),
                radius: 8,
                x: 0,
                y: 3
            )
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

// MARK: - Severity Pill Component

struct SeverityPill: View {
    let severity: Severity
    var small = false

    var body: some View {
        HStack(spacing: small ? 4 : 5) {
            Circle()
                .fill(Color.severityColor(severity))
                .frame(width: small ? 6 : 7, height: small ? 6 : 7)

            Text(severity.label)
                .font(.system(size: small ? 11 : 12, weight: .bold))
                .foregroundStyle(Color.severityFG(severity))
        }
        .padding(.horizontal, small ? 8 : 10)
        .padding(.vertical, small ? 4 : 5)
        .background(Color.severityBG(severity))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.severityBorder(severity), lineWidth: 1)
        )
    }
}

// MARK: - Severity Segment Control

struct SeverityPicker: View {
    @Binding var selection: Severity

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Severity.allCases, id: \.self) { s in
                severityButton(s)
            }
        }
    }

    @ViewBuilder
    private func severityButton(_ s: Severity) -> some View {
        let isSelected = (selection == s)
        Button {
            haptic(.selection)
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selection = s
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.severityColor(s))
                    .frame(width: 8, height: 8)

                Text(s.label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .foregroundStyle(isSelected ? Color.severityColor(s) : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.severityBG(s) : Color(.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.severityColor(s).opacity(0.5) : Color.clear,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header

struct EyebrowLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.0)
            .foregroundStyle(.secondary)
    }
}

// MARK: - IPASS Block Header

struct IPASSHeader: View {
    let letter: String
    let title: String

    private var letterColor: Color {
        switch letter {
        case "I": return Color.red
        case "P": return Color.teal
        case "A": return Color.blue
        case "S": return Color.orange
        default:  return Color.teal
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(letter)
                .font(AppFont.mono(14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(letterColor.gradient)
                )

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(0.8)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Duration Formatter

func formatDuration(_ interval: TimeInterval) -> String {
    let mins = Int(abs(interval) / 60)
    let late = interval < 0
    let h = mins / 60, m = mins % 60
    var parts: [String] = []
    if h > 0 { parts.append("\(h) sa") }
    parts.append("\(m) dk")
    let base = parts.joined(separator: " ")
    return late ? "\(base) gecikti" : "\(base) sonra"
}

// MARK: - Time Formatter

func hhmm(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.timeStyle = .short
    f.dateStyle = .none
    return f.string(from: date)
}

// MARK: - Haptics

enum AppHapticStyle {
    case light, medium, heavy, soft, rigid, selection
}

func haptic(_ style: AppHapticStyle = .light) {
    switch style {
    case .light:
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    case .medium:
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    case .heavy:
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .soft:
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    case .rigid:
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    case .selection:
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

func hapticSelection() {
    UISelectionFeedbackGenerator().selectionChanged()
}

func hapticNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
}

