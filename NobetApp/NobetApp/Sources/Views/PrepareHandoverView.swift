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

    @State private var showEmergencySendAlert = false

    private var missingContingency: Int {
        patients.filter { $0.severity == .unstable && $0.contingency.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    private var canSend: Bool {
        !store.handover.toName.trimmingCharacters(in: .whitespaces).isEmpty && store.handover.status == .draft
    }

    private func executeSend() {
        store.handover.send(to: store.handover.toName)
        ctx.insert(AuditEntry(message: "Devir gönderildi: \(store.handover.toName)"))
        hapticNotification(.success)
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
                                .font(.system(size: 13))
                            Text("\(missingContingency) kararsız hasta için \"olası durumlar\" alanı boş.")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Color.severityFG(.unstable))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.severityBG(.unstable))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.severityBorder(.unstable), lineWidth: 0.5)
                        )
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
                                .foregroundStyle(Color.brand)
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
                    Menu {
                        ShareLink(item: generateReportText()) {
                            Label("Rapor Metnini Paylaş", systemImage: "doc.text")
                        }
                        ShareLink(item: store.exportHandoverJSON(ctx: ctx)) {
                            Label("Devir Verisini Paylaş (JSON)", systemImage: "arrow.triangle.2.circlepath")
                        }
                    } label: {
                        Label("Paylaş", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .alert("Eksik Eylem Planı Uyarısı", isPresented: $showEmergencySendAlert) {
                Button("Acil Devir Yap", role: .destructive) {
                    executeSend()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("\(missingContingency) adet kararsız hastanın olası durum planı henüz girilmedi. Devri yine de göndermek istiyor musunuz?")
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
                    ProgressView().tint(Color.severityFG(.watch))
                    Text("Devir gönderildi. \(store.handover.toName) devralma onayı bekleniyor.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.severityFG(.watch))
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.severityBG(.watch))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.severityBorder(.watch), lineWidth: 0.5)
                )
            case .acknowledged:
                Label("\(store.handover.toName) devri devraldı · \(store.handover.ackTime ?? "")", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.severityFG(.stable))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.severityBG(.stable))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.severityBorder(.stable), lineWidth: 0.5)
                    )
            }
        }
    }

    private var sendButton: some View {
        Group {
            if store.handover.status == .draft {
                Button {
                    guard canSend else { hapticNotification(.error); return }
                    if missingContingency > 0 {
                        showEmergencySendAlert = true
                    } else {
                        executeSend()
                    }
                } label: {
                    Label("Devri gönder", systemImage: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSend ? Color.brand : Color(.systemFill))
                        .foregroundStyle(canSend ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: canSend ? Color.brand.opacity(0.25) : .clear, radius: 8, y: 3)
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
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.brand)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.brand.opacity(0.25), radius: 8, y: 3)
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
                        .font(AppFont.mono(15, weight: .bold))
                        .foregroundStyle(Color.severityFG(patient.severity))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.severityBG(patient.severity))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.severityBorder(patient.severity), lineWidth: 0.5)
                        )

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
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.severityBorder(.unstable), lineWidth: 0.5)
                )
            }
        }
        .padding(16)
        .card()
    }

    private func labeledRow(icon: String, label: String, value: String, isHighlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(isHighlight ? Color.severityFG(.watch) : Color.brand)
                .padding(.top, 3)

            Text(label + ":")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
        }
    }
}
