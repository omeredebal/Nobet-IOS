import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var ctx

    @Query(sort: \AuditEntry.timestamp, order: .reverse) private var auditEntries: [AuditEntry]
    @Query private var allPatients: [Patient]

    @State private var showLogoutAlert = false
    @State private var showClearDataAlert = false
    @State private var showSeedAlert = false
    @State private var seedAlertTitle = ""
    @State private var seedAlertMessage = ""

    var body: some View {
        NavigationStack {
            List {
                // User info
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.userEmail.isEmpty ? "Kullanıcı" : store.userEmail)
                                .font(.system(size: 16, weight: .semibold))
                            Text(store.userRole.label)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // Role
                Section("Hesap") {
                    Picker("Rolün", selection: Binding(
                        get: { store.userRole },
                        set: { newRole in
                            store.userRole = newRole
                            ctx.insert(AuditEntry(message: "Rol değişti: \(newRole.label)"))
                        }
                    )) {
                        ForEach(UserRole.allCases, id: \.self) {
                            Text($0.label).tag($0)
                        }
                    }
                }

                // Data retention & Security
                Section("Gizlilik ve Güvenlik") {
                    Toggle("Biyometrik Kilit (Face ID)", isOn: Binding(
                        get: { store.isBiometricsEnabled },
                        set: { enabled in
                            store.isBiometricsEnabled = enabled
                            if enabled {
                                store.authenticateBiometrics()
                            }
                            ctx.insert(AuditEntry(message: enabled ? "Biyometrik kilit etkinleştirildi" : "Biyometrik kilit devre dışı bırakıldı"))
                        }
                    ))

                    Picker("Otomatik silme", selection: Binding(
                        get: { store.retentionHours },
                        set: { store.retentionHours = $0 }
                    )) {
                        Text("12 saat").tag(12)
                        Text("24 saat").tag(24)
                        Text("48 saat").tag(48)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Color.teal)
                            .font(.system(size: 13))
                        Text("Hasta verileri devirden \(store.retentionHours) saat sonra otomatik silinir. Veriler yalnızca bu cihazda saklanır.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                // Demo & Data Management
                Section("Veri Yönetimi") {
                    Button {
                        let result = store.seedInitialData(ctx: ctx)
                        if result.patientsAdded == 0 && result.membersAdded == 0 {
                            seedAlertTitle = "Demo Veriler Zaten Panoda"
                            seedAlertMessage = "Örnek hastalar (B2, A4, C1) panoda zaten mevcut. Çift kayıt (klon) oluşmaması için tekrar eklenmedi."
                            hapticNotification(.warning)
                        } else {
                            seedAlertTitle = "Demo Veriler Yüklendi"
                            seedAlertMessage = "\(result.patientsAdded) örnek hasta kartı panoya başarıyla eklendi."
                            hapticNotification(.success)
                        }
                        showSeedAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 14, weight: .bold))
                            Text("Örnek Nöbet Verisi Yükle (Demo)")
                                .font(.system(size: 15, weight: .bold))
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        LinearGradient(
                            colors: [Color.teal, Color.teal.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                    Button(role: .destructive) {
                        showClearDataAlert = true
                    } label: {
                        Label("Tüm Hasta Verilerini Temizle", systemImage: "trash")
                    }
                }

                // Audit log button
                Section("Güvenlik ve Denetim") {
                    NavigationLink {
                        AuditLogView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.teal)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Erişim ve Değişiklik Günlüğü")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.primary)

                                Text("Klinik kayıt hareketleri ve denetim izi")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Handover reset
                Section("Nöbet") {
                    Button(role: .destructive) {
                        store.resetHandover()
                        ctx.insert(AuditEntry(message: "Devir sıfırlandı"))
                        hapticNotification(.success)
                    } label: {
                        Label("Devri sıfırla", systemImage: "arrow.counterclockwise")
                    }
                }

                // Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        Label("Çıkış yap", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .alert("Tüm Hasta Verilerini Temizle", isPresented: $showClearDataAlert) {
                Button("Temizle", role: .destructive) {
                    for p in allPatients {
                        ctx.delete(p)
                    }
                    store.resetHandover()
                    ctx.insert(AuditEntry(message: "Tüm hasta verileri manuel olarak temizlendi"))
                    hapticNotification(.success)
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm hasta kartları, görevler ve hatırlatıcılar kalıcı olarak silinecektir.")
            }
            .alert("Çıkış yapmak istediğinizden emin misiniz?", isPresented: $showLogoutAlert) {
                Button("Çıkış yap", role: .destructive) {
                    store.logout()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Nöbet verileri bu cihazda korunacaktır.")
            }
            .alert(seedAlertTitle, isPresented: $showSeedAlert) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(seedAlertMessage)
            }
        }
    }
}

// MARK: - Audit Log View (Erişim ve Değişiklik Günlüğü)

struct AuditLogView: View {
    @Environment(\.modelContext) private var ctx
    @Query(sort: \AuditEntry.timestamp, order: .reverse) private var auditEntries: [AuditEntry]

    @State private var searchText = ""
    @State private var selectedCategory: AuditCategory = .all
    @State private var selectedDateFilter: DateFilterPreset = .all
    @State private var specificDate = Date()
    @State private var showDatePickerSheet = false
    @State private var showClearAlert = false
    @State private var copiedNotice = false

    enum AuditCategory: String, CaseIterable {
        case all       = "Tümü"
        case patient   = "Hasta"
        case taskTimer = "Görev / Süre"
        case handover  = "Devir"
        case security  = "Güvenlik"
    }

    enum DateFilterPreset: String, CaseIterable {
        case all       = "Tüm Tarihler"
        case today     = "Bugün"
        case yesterday = "Dün"
        case specific  = "Tarih Seç"
    }

    private var filteredEntries: [AuditEntry] {
        let cal = Calendar.current
        return auditEntries.filter { entry in
            // Category filter
            let text = entry.message.lowercased()
            let matchesCategory: Bool
            switch selectedCategory {
            case .all:
                matchesCategory = true
            case .patient:
                matchesCategory = text.contains("hasta") || text.contains("yatak") || text.contains("eklendi") || text.contains("güncellendi") || text.contains("taburcu")
            case .taskTimer:
                matchesCategory = text.contains("görev") || text.contains("hatırlatıcı") || text.contains("tamamlandı") || text.contains("ertelendi")
            case .handover:
                matchesCategory = text.contains("devir") || text.contains("devral") || text.contains("sıfırlandı")
            case .security:
                matchesCategory = text.contains("biyometrik") || text.contains("kilit") || text.contains("rol") || text.contains("kod") || text.contains("silme") || text.contains("ayrıldı")
            }
            if !matchesCategory { return false }

            // Date filter
            let matchesDate: Bool
            switch selectedDateFilter {
            case .all:
                matchesDate = true
            case .today:
                matchesDate = cal.isDateInToday(entry.timestamp)
            case .yesterday:
                matchesDate = cal.isDateInYesterday(entry.timestamp)
            case .specific:
                matchesDate = cal.isDate(entry.timestamp, inSameDayAs: specificDate)
            }
            if !matchesDate { return false }

            // Search query filter
            let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
            if query.isEmpty { return true }
            return text.contains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category Filter Bar with auto-scroll
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AuditCategory.allCases, id: \.self) { cat in
                            let isSelected = selectedCategory == cat
                            Button {
                                hapticSelection()
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                    selectedCategory = cat
                                    proxy.scrollTo(cat.rawValue, anchor: .center)
                                }
                            } label: {
                                Text(cat.rawValue)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(isSelected ? Color.teal : Color(.secondarySystemGroupedBackground))
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                            .id(cat.rawValue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                }
            }
            .background(Color(.systemGroupedBackground))

            // Date Filter Query Bar
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.teal)

                ForEach([DateFilterPreset.all, .today, .yesterday], id: \.self) { preset in
                    let isSel = (selectedDateFilter == preset)
                    Button {
                        hapticSelection()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            selectedDateFilter = preset
                        }
                    } label: {
                        Text(preset.rawValue)
                            .font(.system(size: 12, weight: isSel ? .bold : .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isSel ? Color.teal.opacity(0.18) : Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(isSel ? Color.teal : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    haptic()
                    showDatePickerSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedDateFilter == .specific ? formatDateShort(specificDate) : "Tarih Seç")
                            .font(.system(size: 12, weight: selectedDateFilter == .specific ? .bold : .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(selectedDateFilter == .specific ? Color.teal : Color(.tertiarySystemGroupedBackground))
                    .foregroundStyle(selectedDateFilter == .specific ? .white : .secondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                if selectedDateFilter != .all {
                    Button {
                        haptic()
                        withAnimation { selectedDateFilter = .all }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground))

            // Notice / Copied Banner
            if copiedNotice {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.severityColor(.stable))
                    Text("Tüm denetim günlüğü panoya kopyalandı.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.severityColor(.stable))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.severityBG(.stable))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Entries List
            if filteredEntries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("Kayıt bulunamadı")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Seçilen tarih ve kategoride bir işlem kaydı yok." : "Arama kriterine uygun kayıt yok.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    Section {
                        ForEach(filteredEntries) { entry in
                            AuditRow(entry: entry)
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        }
                    } header: {
                        HStack {
                            Text("\(filteredEntries.count) hareket listelendi")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if selectedDateFilter != .all {
                                Text(filterDateTitle)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.teal)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Denetim Günlüğü")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Yatak, hekim veya işlem ara...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        copyFullLog()
                    } label: {
                        Label("Tümünü Kopyala", systemImage: "doc.on.doc")
                    }

                    Button(role: .destructive) {
                        showClearAlert = true
                    } label: {
                        Label("Günlüğü Temizle", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.teal)
                }
            }
        }
        .sheet(isPresented: $showDatePickerSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    DatePicker("Sorgulanacak Tarih", selection: $specificDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding(.horizontal, 16)

                    Button {
                        selectedDateFilter = .specific
                        hapticNotification(.success)
                        showDatePickerSheet = false
                    } label: {
                        Text("Bu Tarihi Sorgula")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.teal)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .navigationTitle("Tarih Filtresi")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { showDatePickerSheet = false }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Denetim Günlüğünü Temizle", isPresented: $showClearAlert) {
            Button("Tümünü Temizle", role: .destructive) {
                for entry in auditEntries {
                    ctx.delete(entry)
                }
                ctx.insert(AuditEntry(message: "Denetim günlüğü sıfırlandı"))
                hapticNotification(.success)
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Yasal ve klinik süreçler için saklanan tüm erişim kayıtları silinecektir.")
        }
    }

    private var filterDateTitle: String {
        switch selectedDateFilter {
        case .all: return ""
        case .today: return "Bugün"
        case .yesterday: return "Dün"
        case .specific: return formatDateShort(specificDate)
        }
    }

    private func formatDateShort(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd MMM"
        return f.string(from: date)
    }

    private func copyFullLog() {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd.MM.yyyy HH:mm:ss"

        var report = "=== NÖBET DEVİR DENETİM İZİ (AUDIT LOG) ===\n"
        report += "Dışa Aktarma Tarihi: \(f.string(from: Date()))\n"
        report += "Toplam Kayıt Sayısı: \(auditEntries.count)\n"
        report += "----------------------------------------\n\n"

        for entry in auditEntries {
            report += "[\(f.string(from: entry.timestamp))] \(entry.message)\n"
        }

        UIPasteboard.general.string = report
        hapticNotification(.success)
        withAnimation { copiedNotice = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copiedNotice = false }
        }
    }
}

// MARK: - Audit Row View

private struct AuditRow: View {
    let entry: AuditEntry

    private var iconInfo: (icon: String, color: Color) {
        let msg = entry.message.lowercased()
        if msg.contains("taburcu") || msg.contains("çıkarıldı") || msg.contains("temizlendi") || msg.contains("sıfırlandı") {
            return ("trash.fill", Color.severityColor(.unstable))
        } else if msg.contains("devraldı") || msg.contains("onay") {
            return ("checkmark.seal.fill", Color.severityColor(.stable))
        } else if msg.contains("hatırlatıcı") {
            return ("bell.badge.fill", Color.severityColor(.watch))
        } else if msg.contains("görev") {
            return ("checklist", Color.teal)
        } else if msg.contains("biyometrik") || msg.contains("kilit") {
            return ("lock.shield.fill", Color.purple)
        } else if msg.contains("ekip") || msg.contains("katıldı") || msg.contains("kod") {
            return ("person.2.badge.key.fill", Color.blue)
        } else if msg.contains("yeni hasta") || msg.contains("eklendi") {
            return ("plus.circle.fill", Color.teal)
        } else {
            return ("doc.text.fill", Color.secondary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category Icon Badge
            Image(systemName: iconInfo.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(iconInfo.color)
                .frame(width: 32, height: 32)
                .background(iconInfo.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text(formatAuditTime(entry.timestamp))
                        .font(AppFont.mono(11, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)

                    Text(formatAuditDate(entry.timestamp))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    private func formatAuditTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func formatAuditDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "dd MMM yyyy"
        return f.string(from: date)
    }
}

