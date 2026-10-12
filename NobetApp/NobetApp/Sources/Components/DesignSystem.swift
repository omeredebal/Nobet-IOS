import SwiftUI

// MARK: - Color System

extension Color {
    /// Adaptive brand medical sapphire blue: deep clinical blue in light mode, luminous sapphire in dark mode.
    static let brand = Color("AccentColor")
    static let teal = brand

    /// Refined Clinical Severity Palette (Elegant, authoritative, non-jarring)
    static func severityColor(_ s: Severity) -> Color {
        switch s {
        case .unstable: Color(red: 0.88, green: 0.16, blue: 0.28) // Crisp Crimson Rose
        case .watch:    Color(red: 0.85, green: 0.46, blue: 0.05) // Warm Amber Ochre
        case .stable:   Color(red: 0.05, green: 0.58, blue: 0.38) // Sage Mint Emerald
        }
    }

    /// High-contrast Foreground Text & Icon Color
    static func severityFG(_ s: Severity) -> Color {
        severityColor(s)
    }

    /// Subtle Translucent Tint Background for Pills & Badges
    static func severityBG(_ s: Severity) -> Color {
        severityColor(s).opacity(0.09)
    }

    /// Ultra-fine Border for Pills & Badges
    static func severityBorder(_ s: Severity) -> Color {
        severityColor(s).opacity(0.22)
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
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color(uiColor: .separator).opacity(scheme == .dark ? 0.35 : 0.18),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: scheme == .dark ? Color.clear : Color.black.opacity(0.03),
                radius: 6,
                x: 0,
                y: 2
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
                .frame(width: small ? 5 : 6, height: small ? 5 : 6)

            Text(severity.label)
                .font(.system(size: small ? 11 : 12, weight: .semibold))
                .foregroundStyle(Color.severityFG(severity))
        }
        .padding(.horizontal, small ? 7 : 9)
        .padding(.vertical, small ? 3 : 4)
        .background(Color.severityBG(severity))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.severityBorder(severity), lineWidth: 0.5)
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
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selection = s
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.severityColor(s))
                    .frame(width: 7, height: 7)

                Text(s.label)
                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.severityColor(s) : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.severityBG(s) : Color(.tertiarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.severityColor(s).opacity(0.4) : Color.clear,
                        lineWidth: 1
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
            .kerning(0.8)
            .foregroundStyle(.secondary)
    }
}

// MARK: - IPASS Block Header

struct IPASSHeader: View {
    let letter: String
    let title: String

    private var letterColor: Color {
        switch letter {
        case "I": return Color(red: 0.88, green: 0.16, blue: 0.28)
        case "P": return Color.brand
        case "A": return Color(red: 0.20, green: 0.50, blue: 0.85)
        case "S": return Color(red: 0.85, green: 0.46, blue: 0.05)
        default:  return Color.brand
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(letter)
                .font(AppFont.mono(12, weight: .bold))
                .foregroundStyle(letterColor)
                .frame(width: 22, height: 22)
                .background(letterColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.7)
                .foregroundStyle(.secondary)

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

