import SwiftUI
import SwiftData

struct ReceiveHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(AppStore.self) private var store

    @Query private var allPatients: [Patient]

    @State private var receiverRole: UserRole = .asistan

    private var patients: [Patient] {
        allPatients.sorted {
            if $0.severity.sortOrder != $1.severity.sortOrder {
                return $0.severity.sortOrder < $1.severity.sortOrder
            }
            return $0.bed < $1.bed
        }
    }

    private var allAcknowledged: Bool {
        patients.allSatisfy(\.acknowledged)
    }

    private var canConfirm: Bool {
        allAcknowledged && receiverRole.isPhysician && store.handover.status == .sent
    }

    private var isDone: Bool { store.handover.status == .acknowledged }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Receiver role
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Devralanın rolü")
                        Picker("Rol", selection: $receiverRole) {
                            ForEach(UserRole.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                        )
                        .disabled(isDone)
                    }

                    // Physician-only warning
                    if !receiverRole.isPhysician && !isDone {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                            Text("Devralma onayını yalnızca hekim rolleri verebilir. İntörn ve öğrenciler devri okuyabilir.")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Done banner
                    if isDone {
                        Label("Devralındı · \(store.handover.ackTime ?? "")", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.severityFG(.stable))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.severityBG(.stable))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Progress
                    if !isDone {
                        HStack {
                            Text("\(patients.filter(\.acknowledged).count) / \(patients.count) okundu")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Tümünü Okundu Yap") {
                                for p in patients { p.acknowledged = true }
                                hapticNotification(.success)
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.teal)
                        }
                    }

                    // Patient list
                    ForEach(patients) { p in
                        ReceivePatientCard(patient: p, locked: isDone)
                    }
                }
                .padding(16)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(store.handover.toName.isEmpty ? "Devralan" : store.handover.toName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if !isDone {
                    Button {
                        guard canConfirm else { hapticNotification(.error); return }
                        store.handover.acknowledge()
                        ctx.insert(AuditEntry(message: "\(store.handover.toName) devri devraldı"))
                        hapticNotification(.success)
                    } label: {
                        Label("Devraldım", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(canConfirm ? Color.teal : Color(.systemFill))
                            .foregroundStyle(canConfirm ? .white : .secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(!canConfirm)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .background(
                        LinearGradient(
                            colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Receive Patient Card

private struct ReceivePatientCard: View {
    @Bindable var patient: Patient
    let locked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(patient.bed) · \(patient.age) \(patient.sex.rawValue)")
                    .font(AppFont.mono(13, weight: .medium))
                Spacer()
                SeverityPill(severity: patient.severity, small: true)
            }

            Text(patient.problem)
                .font(.system(size: 15, weight: .semibold))

            if !patient.summary.isEmpty {
                Text(patient.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            if !patient.contingency.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                    Text(patient.contingency)
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
            }

            Divider()

            // Ack toggle
            Button {
                guard !locked else { return }
                patient.acknowledged.toggle()
                haptic()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: patient.acknowledged ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundStyle(patient.acknowledged ? Color.teal : .secondary)
                    Text(patient.acknowledged ? "Okundu" : "Okudum olarak işaretle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(patient.acknowledged ? Color.teal : .primary)
                }
            }
            .buttonStyle(.plain)
            .disabled(locked)
        }
        .padding(14)
        .card()
    }
}
