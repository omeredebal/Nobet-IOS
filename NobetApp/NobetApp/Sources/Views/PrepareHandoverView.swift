import SwiftUI
import SwiftData

struct PrepareHandoverView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(AppStore.self) private var store

    @Query private var allPatients: [Patient]
    @Query private var members: [TeamMember]

    private var patients: [Patient] {
        allPatients.sorted {
            if $0.severity.sortOrder != $1.severity.sortOrder {
                return $0.severity.sortOrder < $1.severity.sortOrder
            }
            return $0.bed < $1.bed
        }
    }

    private var missingContingency: Int {
        patients.filter { $0.severity == .unstable && $0.contingency.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var canSend: Bool {
        missingContingency == 0 && !store.handover.toName.isEmpty && store.handover.status == .draft
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    statusBanner

                    // Recipient
                    VStack(alignment: .leading, spacing: 6) {
                        EyebrowLabel(text: "Devralan")
                        if members.isEmpty {
                            TextField("Hekim adı", text: recipientBinding)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                                )
                        } else {
                            Picker("Devralan", selection: recipientBinding) {
                                Text("Seçiniz").tag("")
                                ForEach(members) { m in
                                    Text("\(m.name) · \(m.role.label)").tag(m.name)
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
                        }
                    }

                    // Warning
                    if missingContingency > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("\(missingContingency) kararsız hasta için \"olası durumlar\" alanı boş.")
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.severityFG(.unstable))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.severityBG(.unstable))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Patient summaries header
                    HStack {
                        EyebrowLabel(text: "\(patients.count) hasta · \(hhmm())")
                        Spacer()
                        Button {
                            UIPasteboard.general.string = generateReportText()
                            hapticNotification(.success)
                        } label: {
                            Label("Raporu Kopyala", systemImage: "doc.on.doc")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.teal)
                        }
                    }

                    ForEach(patients) { p in
                        HandoverPatientCard(patient: p)
                    }
                }
                .padding(16)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Devir Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: generateReportText()) {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .overlay(alignment: .bottom) {
                sendButton
            }
        }
    }

    private func generateReportText() -> String {
        var lines: [String] = []
        lines.append("🏥 NÖBET DEVİR RAPORU")
        lines.append("📅 Tarih: \(hhmm())")
        lines.append("👤 Devreden: \(store.userEmail.isEmpty ? "Nöbetçi Hekim" : store.userEmail) (\(store.userRole.label))")
        if !store.handover.toName.isEmpty {
            lines.append("🎯 Devralan: \(store.handover.toName)")
        }
        lines.append("📊 Toplam: \(patients.count) hasta (\(patients.filter{$0.severity == .unstable}.count) Kararsız, \(patients.filter{$0.severity == .watch}.count) İzlemde, \(patients.filter{$0.severity == .stable}.count) Stabil)")
        lines.append(String(repeating: "═", count: 30))

        for p in patients {
            lines.append("\n[\(p.bed)] \(p.age) \(p.sex.rawValue) · [\(p.severity.label.uppercased())]")
            lines.append("Sorun: \(p.problem)")
            if !p.summary.isEmpty {
                lines.append("Özet: \(p.summary)")
            }
            let open = p.tasks.filter { !$0.isDone }
            if !open.isEmpty {
                lines.append("Yapılacaklar: " + open.map { "• " + $0.text }.joined(separator: "; "))
            }
            if !p.contingency.isEmpty {
                lines.append("Olası Durum: \(p.contingency)")
            }
            lines.append(String(repeating: "─", count: 24))
        }
        lines.append("\n🔒 Tıbbi cihaz değildir. Klinik karar destek devir özetidir.")
        return lines.joined(separator: "\n")
    }

    private var recipientBinding: Binding<String> {
        Binding(
            get: { store.handover.toName },
            set: { store.handover.toName = $0 }
        )
    }

    private var statusBanner: some View {
        Group {
            switch store.handover.status {
            case .draft:
                EmptyView()
            case .sent:
                HStack(spacing: 8) {
                    ProgressView().tint(.orange)
                    Text("Devir gönderildi. \(store.handover.toName) devralma onayı bekleniyor.")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            case .acknowledged:
                Label("\(store.handover.toName) devri devraldı · \(store.handover.ackTime ?? "")", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.severityFG(.stable))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.severityBG(.stable))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var sendButton: some View {
        Group {
            if store.handover.status == .draft {
                Button {
                    guard canSend else { hapticNotification(.error); return }
                    store.handover.send(to: store.handover.toName)
                    ctx.insert(AuditEntry(message: "Devir gönderildi: \(store.handover.toName)"))
                    hapticNotification(.success)
                } label: {
                    Label("Devri gönder", systemImage: "paperplane.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSend ? Color.teal : Color(.systemFill))
                        .foregroundStyle(canSend ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSend)
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            } else if store.handover.status == .sent {
                Button {
                    store.showReceiveSheet = true
                } label: {
                    Label("Devralan görünümünü aç", systemImage: "arrow.right.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .background(
                    LinearGradient(
                        colors: [Color(.systemGroupedBackground).opacity(0), Color(.systemGroupedBackground)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .sheet(isPresented: Binding(
                    get: { store.showReceiveSheet },
                    set: { store.showReceiveSheet = $0 }
                )) {
                    ReceiveHandoverView()
                }
            }
        }
    }
}

// MARK: - Handover Patient Card

private struct HandoverPatientCard: View {
    let patient: Patient

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Text(patient.bed)
                        .font(AppFont.mono(16, weight: .bold))
                        .foregroundStyle(Color.severityColor(patient.severity))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.severityBG(patient.severity))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                    Text("\(patient.age) Yaş · \(patient.sex == .erkek ? "Erkek" : "Kadın")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                SeverityPill(severity: patient.severity, small: true)
            }

            Text(patient.problem)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            if !patient.summary.isEmpty {
                labeledRow(icon: "doc.text.fill", label: "Özet", value: patient.summary)
            }

            let openTasks = patient.tasks.filter { !$0.isDone }
            if !openTasks.isEmpty {
                labeledRow(icon: "checklist", label: "Yapılacak", value: openTasks.map(\.text).joined(separator: " • "))
            }

            if !patient.contingency.isEmpty {
                labeledRow(icon: "arrow.triangle.branch", label: "Olası Durum", value: patient.contingency, isHighlight: true)
            } else if patient.severity == .unstable {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("Acil durum planı eksik!")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.severityFG(.unstable))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.severityBG(.unstable))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(16)
        .card()
    }

    private func labeledRow(icon: String, label: String, value: String, isHighlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isHighlight ? .orange : Color.teal)
                .padding(.top, 3)

            Text(label + ":")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(isHighlight ? .primary : .primary)
        }
    }
}
