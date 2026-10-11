import SwiftUI

// MARK: - Patient Card

struct PatientCardView: View {
    let patient: Patient
    @State private var tick = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Bed Badge with severity tint
            bedBadge

            // Patient Info & Clinical details
            VStack(alignment: .leading, spacing: 6) {
                // Header: Demographics + Severity Pill
                HStack(alignment: .center) {
                    HStack(spacing: 6) {
                        Image(systemName: patient.sex == .erkek ? "figure.male" : "figure.female")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("\(patient.age) Yaş · \(patient.sex == .erkek ? "Erkek" : "Kadın")")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    SeverityPill(severity: patient.severity, small: true)
                }

                // Problem / Primary Clinical Issue
                Text(patient.problem)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Optional Summary preview
                if !patient.summary.isEmpty {
                    Text(patient.summary)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                // Status Chips Row (Tasks, Timer, Contingency)
                HStack(spacing: 8) {
                    // Task badge
                    HStack(spacing: 4) {
                        Image(systemName: patient.openTaskCount == 0 ? "checkmark.circle.fill" : "checklist")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(patient.openTaskCount == 0 ? Color.severityFG(.stable) : .secondary)

                        Text(patient.openTaskCount == 0 ? "Tamam" : "\(patient.openTaskCount) görev")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(patient.openTaskCount == 0 ? Color.severityFG(.stable) : .secondary)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Capsule())

                    // Timer badge
                    if let t = patient.nextTimer {
                        timerBadge(t)
                    }

                    // Unstable missing contingency warning
                    if patient.severity == .unstable && patient.contingency.trimmingCharacters(in: .whitespaces).isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("Plan eksik")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Color.severityFG(.unstable))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.severityBG(.unstable))
                        .clipShape(Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .card()
        .contentShape(Rectangle())
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            tick = Date()
        }
    }

    // MARK: - Subviews

    private var bedBadge: some View {
        VStack(spacing: 2) {
            Text("YATAK")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.severityFG(patient.severity).opacity(0.8))
                .kerning(0.5)

            Text(patient.bed)
                .font(AppFont.mono(20, weight: .bold))
                .foregroundStyle(Color.severityFG(patient.severity))
        }
        .frame(width: 54, height: 54)
        .background(Color.severityBG(patient.severity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.severityBorder(patient.severity), lineWidth: 1.5)
        )
    }

    private func timerBadge(_ t: PatientTimer) -> some View {
        let late = t.due < tick
        return HStack(spacing: 4) {
            Image(systemName: late ? "exclamationmark.circle.fill" : "clock.fill")
                .font(.system(size: 10))

            Text(formatDuration(t.due.timeIntervalSince(tick)))
                .font(.system(size: 11, weight: late ? .bold : .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(late ? Color.severityFG(.unstable) : Color.teal)
        .background(late ? Color.severityBG(.unstable) : Color.teal.opacity(0.12))
        .clipShape(Capsule())
    }
}
