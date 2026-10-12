import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

// MARK: - Offline QR Helper

func generateQRCode(from string: String) -> UIImage? {
    let filter = CIFilter.qrCodeGenerator()
    filter.message = Data(string.utf8)
    filter.correctionLevel = "M"
    guard let outputImage = filter.outputImage else { return nil }
    let transform = CGAffineTransform(scaleX: 10, y: 10)
    let scaledImage = outputImage.transformed(by: transform)
    let context = CIContext()
    guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
    return UIImage(cgImage: cgImage)
}

// MARK: - Team View

struct TeamView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.modelContext) private var ctx

    @Query(sort: \TeamMember.joinedAt) private var members: [TeamMember]

    @State private var showJoinTeam = false
    @State private var showCreateTeam = false
    @State private var showQRCodeSheet = false
    @State private var showRegenAlert = false
    @State private var showLeaveTeamAlert = false
    @State private var copyFeedback = false

    private var shareMessage: String {
        """
        Nöbet Devir Ekip Daveti 🏥
        Ekip: \(store.teamName)
        Birim: \(store.teamDepartment)
        Davet Kodu: \(store.inviteCode)

        Nöbet Devir uygulamasında Ekip sekmesine gidin, 'Davet Kodu ile Katıl' alanına '\(store.inviteCode)' kodunu girerek nöbet havuzumuza katılın.
        """
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: 1. Team Header Banner
                    teamHeaderCard

                    // MARK: 2. Invite Code & Sharing Panel
                    inviteCodeCard

                    // MARK: 3. Join Team with Code Action Button
                    joinTeamButtonCard

                    // MARK: 4. Week Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        EyebrowLabel(text: "Bu hafta nöbetlerim")
                        weekGrid
                    }
                    .padding(16)
                    .card()
                    .padding(.horizontal, 16)

                    // MARK: 5. Members List
                    membersCard

                    // MARK: 6. Leave Team Action
                    Button(role: .destructive) {
                        showLeaveTeamAlert = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "door.left.hand.open")
                            Text("Ekipten Ayrıl")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.severityFG(.unstable))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.severityBG(.unstable))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.severityBorder(.unstable), lineWidth: 0.5)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Ekip")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showJoinTeam) {
                JoinTeamSheet()
            }
            .sheet(isPresented: $showCreateTeam) {
                CreateTeamSheet()
            }
            .sheet(isPresented: $showQRCodeSheet) {
                TeamQRCodeSheet()
            }
            .alert("Davet Kodunu Yenile", isPresented: $showRegenAlert) {
                Button("Yeni Kod Üret", role: .destructive) {
                    _ = store.regenerateInviteCode(ctx: ctx)
                    hapticNotification(.success)
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Eski davet kodu geçersiz kılınacaktır. Yeni bir 8 haneli kod üretilecek.")
            }
            .alert("Ekipten Ayrıl", isPresented: $showLeaveTeamAlert) {
                Button("Ekipten Ayrıl", role: .destructive) {
                    store.leaveTeam(ctx: ctx)
                    hapticNotification(.success)
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("\(store.teamName) ekibinden ayrılmak istediğinizden emin misiniz? Nöbet listeniz ve paylaşılan devir havuzundan çıkacaksınız.")
            }
        }
    }

    // MARK: - Subviews

    private var teamHeaderCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Color.brand.opacity(0.10))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "person.3.sequence.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.brand)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(store.teamName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)

                Text(store.teamDepartment)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button {
                    showCreateTeam = true
                } label: {
                    Label("Yeni Ekip Kur", systemImage: "plus.square.dashed")
                }

                Button {
                    showQRCodeSheet = true
                } label: {
                    Label("Karekod Göster (QR)", systemImage: "qrcode")
                }

                Button {
                    showRegenAlert = true
                } label: {
                    Label("Davet Kodunu Yenile", systemImage: "arrow.triangle.2.circlepath")
                }

                Divider()

                Button(role: .destructive) {
                    showLeaveTeamAlert = true
                } label: {
                    Label("Ekipten Ayrıl", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .card()
        .padding(.horizontal, 16)
    }

    private var inviteCodeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Ekip Davet Kodu")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 10, weight: .bold))
                    Text("Çevrimdışı Aktif")
                        .font(.system(size: 11, weight: .bold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.severityBG(.stable))
                .foregroundStyle(Color.severityFG(.stable))
                .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Text(store.inviteCode)
                    .font(AppFont.mono(20, weight: .bold))
                    .foregroundStyle(Color.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.brand.opacity(0.3), lineWidth: 0.5)
                    )

                Spacer()

                // QR Code sheet button
                Button {
                    haptic()
                    showQRCodeSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                        Text("QR")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.brand.opacity(0.10))
                    .foregroundStyle(Color.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // Share link button
                ShareLink(item: shareMessage) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Paylaş")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.brand)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)

                // Copy button
                Button {
                    UIPasteboard.general.string = store.inviteCode
                    haptic()
                    withAnimation { copyFeedback = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copyFeedback = false }
                    }
                } label: {
                    Image(systemName: copyFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(9)
                        .background(copyFeedback ? Color.severityBG(.stable) : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(copyFeedback ? Color.severityFG(.stable) : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Text("İnternet veya sunucu gerekmez. Nöbet arkadaşınız bu karekodu okutarak veya kodu girerek aynı ekibin nöbet havuzuna dahil olur.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .card()
        .padding(.horizontal, 16)
    }

    private var joinTeamButtonCard: some View {
        Button {
            haptic()
            showJoinTeam = true
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.brand.opacity(0.10))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.brand)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Davet Kodu ile Ekibe Katıl")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("Kıdemlinizden aldığınız kodla başka bir gruba dahil olun")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .card()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                EyebrowLabel(text: "Ekip Üyeleri · \(members.count) hekim")
                Spacer()
            }

            if members.isEmpty {
                Text("Henüz ekip üyesi eklenmedi.")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(members) { member in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color.brand.opacity(0.10))
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Text(member.name.prefix(1).uppercased())
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(Color.brand)
                                    )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(.primary)

                                    if member.name.lowercased() == store.userEmail.lowercased() {
                                        Text("(Sen)")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Color.brand)
                                    }
                                }

                                Text(member.role.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(member.role.label)
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color.brand.opacity(0.08))
                                .foregroundStyle(Color.brand)
                                .clipShape(Capsule())
                        }
                        if member.id != members.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .card()
        .padding(.horizontal, 16)
    }

    // MARK: - Week grid

    private var weekGrid: some View {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let today = cal.startOfDay(for: Date())
        let todayWeekday = cal.component(.weekday, from: today)
        let offsetToMonday = (todayWeekday == 1) ? -6 : (2 - todayWeekday)
        let monday = cal.date(byAdding: .day, value: offsetToMonday, to: today)!
        let days = (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday)! }
        let shortSymbols = ["Pt","Sa","Ça","Pe","Cu","Ct","Pz"]

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, date in
                    let isToday = cal.isDateInToday(date)
                    let isOnDuty = store.dutyDays.contains(i)
                    Button {
                        haptic()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            store.toggleDutyDay(i)
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(shortSymbols[i])
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(isOnDuty ? .white : .secondary)
                            Text("\(cal.component(.day, from: date))")
                                .font(AppFont.mono(14, weight: .medium))
                                .foregroundStyle(isOnDuty ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isOnDuty ? Color.brand : (isToday ? Color.brand.opacity(0.10) : Color(.secondarySystemGroupedBackground)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isToday && !isOnDuty ? Color.brand.opacity(0.4) : Color.clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Nöbet günlerinizi belirlemek için günlere dokunun.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Team QR Code Sheet (Çevrimdışı Eşleşme)

struct TeamQRCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    private var qrPayload: String {
        "nobet://join?code=\(store.inviteCode)&team=\(store.teamName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&dept=\(store.teamDepartment.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()

                if let image = generateQRCode(from: qrPayload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 10, y: 5)
                }

                VStack(spacing: 6) {
                    Text(store.inviteCode)
                        .font(AppFont.mono(30, weight: .bold))
                        .foregroundStyle(Color.brand)

                    Text(store.teamName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(store.teamDepartment)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 13, weight: .bold))
                        Text("100% Çevrimdışı Çalışır (Sıfır Bulut / Sıfır Sunucu)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Color.brand)

                    Text("Hastane içinde internet veya merkezi sunucuya ihtiyaç duymadan, diğer hekim ekranınızdaki bu karekodu okutarak veya altındaki kodu girerek anında bu ekibe katılır.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Çevrimdışı Eşleşme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Join Team Sheet (Davet Kodu ile Katılma)

struct JoinTeamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(AppStore.self) private var store

    @State private var code = ""
    @State private var userName = ""
    @State private var userRole: UserRole = .asistan
    @State private var errorMessage = ""
    @State private var successBanner = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .center, spacing: 10) {
                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.brand)
                            .padding(.top, 6)

                        Text("Ekibe Katıl")
                            .font(.system(size: 20, weight: .bold))

                        Text("Nöbet arkadaşınızın veya servis sorumlunuzun paylaştığı davet kodunu girin.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.brand)
                        Text("İnternet veya sunucu gerekmez. Yanınızdaki hekimin ekranındaki kodu girerek veya AirDrop/Bluetooth ile paylaşılan kodu kullanarak anında aynı nöbet ekibine dahil olursunuz.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Davet Kodu") {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(Color.brand)

                        TextField("Örn. NBT-4K9Q", text: $code)
                            .font(AppFont.mono(17, weight: .bold))
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)

                        if !code.isEmpty {
                            Button {
                                code = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button {
                            if let clip = UIPasteboard.general.string {
                                code = clip.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                                haptic()
                            }
                        } label: {
                            Text("Yapıştır")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.brand)
                        }
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                    }
                }

                Section("Katılan Hekim Bilgileri") {
                    TextField("Ad Soyad", text: $userName)
                    Picker("Rol", selection: $userRole) {
                        ForEach(UserRole.allCases, id: \.self) {
                            Text($0.label).tag($0)
                        }
                    }
                }

                Section {
                    Button {
                        submitJoin()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Doğrula ve Ekibe Katıl")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(canSubmit ? Color.brand : Color.secondary.opacity(0.4))
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Ekibe Katıl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear {
                if userName.isEmpty {
                    userName = store.userEmail
                }
                userRole = store.userRole
            }
        }
    }

    private var canSubmit: Bool {
        let clean = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count >= 4 && !userName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submitJoin() {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let success = store.joinTeamWithCode(code: cleanCode, userName: userName, userRole: userRole, ctx: ctx)
        if success {
            if !store.isLoggedIn {
                store.login(email: userName, role: userRole)
            }
            hapticNotification(.success)
            dismiss()
        } else {
            errorMessage = "Geçersiz davet kodu. Lütfen kontrol edip tekrar deneyin."
            hapticNotification(.error)
        }
    }
}

// MARK: - Create Team Sheet (Yeni Ekip Kurma)

struct CreateTeamSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(AppStore.self) private var store

    @State private var teamName = ""
    @State private var department = "Acil Tıp Kliniği"

    private let departments = [
        "Acil Tıp Kliniği",
        "Yoğun Bakım Ünitesi",
        "İç Hastalıkları (Dahiliye)",
        "Genel Cerrahi",
        "Pediatri (Çocuk Acil)",
        "Kardiyoloji",
        "Anestezi ve Reanimasyon",
        "Nöroloji"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Yeni Ekip Detayları") {
                    TextField("Ekip Adı (örn: Acil Nöbet A Grubu)", text: $teamName)
                    Picker("Birim / Klinik", selection: $department) {
                        ForEach(departments, id: \.self) { dept in
                            Text(dept).tag(dept)
                        }
                    }
                }

                Section(footer: Text("Yeni ekip kurulduğunda otomatik olarak benzersiz bir davet kodu üretilir ve nöbet arkadaşlarınızla paylaşılabilir.")) {
                    Button {
                        let finalName = teamName.trimmingCharacters(in: .whitespaces).isEmpty ? "Nöbet Ekibi" : teamName
                        store.createNewTeam(name: finalName, department: department, ctx: ctx)
                        hapticNotification(.success)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Ekibi Oluştur")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Color.brand)
                }
            }
            .navigationTitle("Yeni Ekip Kur")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .onAppear {
                teamName = store.teamName
            }
        }
    }
}
