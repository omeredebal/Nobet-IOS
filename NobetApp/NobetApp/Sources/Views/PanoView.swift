import SwiftUI
import SwiftData

struct PanoView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var ctx

    @Query private var allPatients: [Patient]
    @Query private var auditEntries: [AuditEntry]

    @State private var searchText = ""
    @State private var filterSeverity: Severity? = nil

    private var filteredPatients: [Patient] {
        var list = allPatients
        if let filter = filterSeverity {
            list = list.filter { $0.severity == filter }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.bed.lowercased().contains(query) ||
                $0.problem.lowercased().contains(query) ||
                $0.summary.lowercased().contains(query)
            }
        }
        return list.sorted {
            if $0.severity.sortOrder != $1.severity.sortOrder {
                return $0.severity.sortOrder < $1.severity.sortOrder
            }
            return $0.bed < $1.bed
        }
    }

    private var unstable: Int { allPatients.filter { $0.severity == .unstable }.count }
    private var watch: Int    { allPatients.filter { $0.severity == .watch }.count }
    private var stable: Int   { allPatients.filter { $0.severity == .stable }.count }

    var body: some View {
        @Bindable var s = store
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Handover notification banner if active
                    if store.handover.status != .draft {
                        handoverStatusBanner
                            .padding(.horizontal, 16)
                    }

                    // Summary status cards (Interactive)
                    HStack(spacing: 10) {
                        Button {
                            haptic(.selection)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                filterSeverity = (filterSeverity == .unstable) ? nil : .unstable
                            }
                        } label: {
                            SummaryCell(count: unstable, label: "Kararsız", severity: .unstable, isSelected: filterSeverity == .unstable)
                        }
                        .buttonStyle(.plain)

                        Button {
                            haptic(.selection)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                filterSeverity = (filterSeverity == .watch) ? nil : .watch
                            }
                        } label: {
                            SummaryCell(count: watch, label: "İzlemde", severity: .watch, isSelected: filterSeverity == .watch)
                        }
                        .buttonStyle(.plain)

                        Button {
                            haptic(.selection)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                filterSeverity = (filterSeverity == .stable) ? nil : .stable
                            }
                        } label: {
                            SummaryCell(count: stable, label: "Stabil", severity: .stable, isSelected: filterSeverity == .stable)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // Filter chips row
                    filterChipsRow
                        .padding(.horizontal, 16)

                    // Patient list
                    if filteredPatients.isEmpty {
                        emptyState
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                EyebrowLabel(text: "Hastalar · \(filteredPatients.count) Kart")
                                Spacer()
                                Text("Şiddete göre sıralı")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 16)

                            ForEach(filteredPatients) { patient in
                                NavigationLink(value: patient) {
                                    PatientCardView(patient: patient)
                                        .padding(.horizontal, 16)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Menu("Şiddeti Değiştir") {
                                        Button("Kararsız ⚠️") {
                                            patient.severity = .unstable
                                            ctx.insert(AuditEntry(message: "\(patient.bed) şiddet: Kararsız"))
                                            haptic()
                                        }
                                        Button("İzlemde 👁️") {
                                            patient.severity = .watch
                                            ctx.insert(AuditEntry(message: "\(patient.bed) şiddet: İzlemde"))
                                            haptic()
                                        }
                                        Button("Stabil ✅") {
                                            patient.severity = .stable
                                            ctx.insert(AuditEntry(message: "\(patient.bed) şiddet: Stabil"))
                                            haptic()
                                        }
                                    }

                                    Button {
                                        let text = "[\(patient.bed)] \(patient.age) \(patient.sex.rawValue) - \(patient.problem) (\(patient.severity.label))\nÖzet: \(patient.summary)"
                                        UIPasteboard.general.string = text
                                        haptic()
                                    } label: {
                                        Label("Kartı Kopyala", systemImage: "doc.on.doc")
                                    }

                                    Divider()

                                    Button(role: .destructive) {
                                        ctx.delete(patient)
                                        ctx.insert(AuditEntry(message: "\(patient.bed) kartı silindi"))
                                        hapticNotification(.success)
                                    } label: {
                                        Label("Hastayı Çıkar / Sil", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }

                    // Privacy disclaimer card
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.teal)

                        Text("Yatak, yaş ve cinsiyet dışında kimlik bilgisi toplanmaz. Klinik karar destek amaçlıdır.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .padding(.bottom, 110) // room for floating bottom dock
            }
            .searchable(text: $searchText, prompt: "Yatak veya tanı ara...")
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Nöbet Devir")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    onlineBadge
                }
            }
            .navigationDestination(for: Patient.self) { patient in
                PatientDetailView(patient: patient)
            }
            .overlay(alignment: .bottom) {
                floatingBottomDock
            }
            .sheet(isPresented: $s.showAddPatient) {
                AddPatientView()
            }
            .sheet(isPresented: $s.showPrepareSheet) {
                PrepareHandoverView()
            }
        }
    }

    // MARK: - Sub-views

    private var handoverStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: store.handover.status == .sent ? "paperplane.circle.fill" : "checkmark.seal.fill")
                .font(.system(size: 24))
                .foregroundStyle(store.handover.status == .sent ? .orange : Color.severityFG(.stable))

            VStack(alignment: .leading, spacing: 2) {
                Text(store.handover.status == .sent ? "Devir Gönderildi" : "Devir Tamamlandı")
                    .font(.system(size: 14, weight: .bold))
                Text(store.handover.status == .sent ? "\(store.handover.toName) hekimin devralma onayı bekleniyor." : "\(store.handover.toName) devraldı (\(store.handover.ackTime ?? ""))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Görüntüle") {
                store.showPrepareSheet = true
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 2)
        }
        .padding(14)
        .background(store.handover.status == .sent ? Color.orange.opacity(0.12) : Color.severityBG(.stable))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke((store.handover.status == .sent ? Color.orange : Color.severityFG(.stable)).opacity(0.3), lineWidth: 1)
        )
    }

    private var filterChipsRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Tümü (\(allPatients.count))", isSelected: filterSeverity == nil) {
                        haptic(.selection)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            filterSeverity = nil
                            proxy.scrollTo("all", anchor: .center)
                        }
                    }
                    .id("all")

                    FilterChip(title: "Kararsız (\(unstable))", isSelected: filterSeverity == .unstable, color: Color.severityFG(.unstable)) {
                        haptic(.selection)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            filterSeverity = .unstable
                            proxy.scrollTo("unstable", anchor: .center)
                        }
                    }
                    .id("unstable")

                    FilterChip(title: "İzlemde (\(watch))", isSelected: filterSeverity == .watch, color: Color.severityFG(.watch)) {
                        haptic(.selection)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            filterSeverity = .watch
                            proxy.scrollTo("watch", anchor: .center)
                        }
                    }
                    .id("watch")

                    FilterChip(title: "Stabil (\(stable))", isSelected: filterSeverity == .stable, color: Color.severityFG(.stable)) {
                        haptic(.selection)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                            filterSeverity = .stable
                            proxy.scrollTo("stable", anchor: .center)
                        }
                    }
                    .id("stable")
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: filterSeverity) { _, newSeverity in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                    if let s = newSeverity {
                        switch s {
                        case .unstable: proxy.scrollTo("unstable", anchor: .center)
                        case .watch:    proxy.scrollTo("watch", anchor: .center)
                        case .stable:   proxy.scrollTo("stable", anchor: .center)
                        }
                    } else {
                        proxy.scrollTo("all", anchor: .center)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "stethoscope" : "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.teal.opacity(0.6))
                .padding(.bottom, 4)

            Text(searchText.isEmpty ? "Aktif Hasta Yok" : "Eşleşen Hasta Bulunamadı")
                .font(.system(size: 18, weight: .bold))

            Text(searchText.isEmpty ? "Nöbet listenize ilk hastayı ekleyin veya gerçekçi klinik vakaları inceleyin." : "Farklı bir yatak no veya klinik tanı aramayı deneyin.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if allPatients.isEmpty {
                Button {
                    hapticNotification(.success)
                    store.seedInitialData(ctx: ctx)
                } label: {
                    Label("Örnek Nöbet Verisi Yükle (Demo)", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.teal.opacity(0.3), radius: 6, y: 3)
                }
                .padding(.top, 8)
            }
        }
        .padding(36)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var onlineBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color.teal)
                .frame(width: 7, height: 7)

            Text("Çevrimdışı")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.teal)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.teal.opacity(0.12))
        .clipShape(Capsule())
    }

    private var floatingBottomDock: some View {
        HStack(spacing: 12) {
            Button {
                haptic(.medium)
                store.showAddPatient = true
            } label: {
                Label("Hasta Ekle", systemImage: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    )
            }

            Button {
                haptic(.medium)
                store.showPrepareSheet = true
            } label: {
                Label("Devri Hazırla", systemImage: "arrow.right.doc.on.clipboard.fill")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.teal.opacity(0.35), radius: 6, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Summary Cell

private struct SummaryCell: View {
    let count: Int
    let label: String
    let severity: Severity
    var isSelected: Bool = false

    private var iconName: String {
        switch severity {
        case .unstable: return "exclamationmark.triangle.fill"
        case .watch:    return "eye.fill"
        case .stable:   return "checkmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: 5) {
            ZStack {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.severityColor(severity))

                if isSelected {
                    HStack {
                        Spacer()
                        Circle()
                            .fill(Color.severityColor(severity))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Text("\(count)")
                .font(AppFont.mono(26, weight: .bold))
                .foregroundStyle(Color.severityColor(severity))
                .multilineTextAlignment(.center)

            Text(label)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.severityColor(severity) : .secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.severityBG(severity) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? Color.severityColor(severity) : Color.severityBorder(severity).opacity(0.4),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: isSelected ? Color.severityColor(severity).opacity(0.12) : .clear, radius: 4)
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    var color: Color = Color.teal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? color.opacity(0.16) : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? color : .secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
