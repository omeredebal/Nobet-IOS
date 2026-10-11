import Foundation
import Observation
import SwiftUI
import SwiftData
import LocalAuthentication

// MARK: - AppStore

@MainActor
@Observable
final class AppStore {

    // MARK: Auth / User
    var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "is_logged_in") {
        didSet { UserDefaults.standard.set(isLoggedIn, forKey: "is_logged_in") }
    }

    var userEmail: String = UserDefaults.standard.string(forKey: "user_email") ?? "" {
        didSet { UserDefaults.standard.set(userEmail, forKey: "user_email") }
    }

    var userRole: UserRole = UserRole(rawValue: UserDefaults.standard.string(forKey: "user_role") ?? "") ?? .asistan {
        didSet { UserDefaults.standard.set(userRole.rawValue, forKey: "user_role") }
    }

    var retentionHours: Int = {
        let h = UserDefaults.standard.integer(forKey: "retention_hours")
        return h == 0 ? 24 : h
    }() {
        didSet { UserDefaults.standard.set(retentionHours, forKey: "retention_hours") }
    }

    // MARK: Team & Invite
    var teamName: String = UserDefaults.standard.string(forKey: "team_name") ?? "Acil Servis Nöbet Ekibi" {
        didSet { UserDefaults.standard.set(teamName, forKey: "team_name") }
    }

    var teamDepartment: String = UserDefaults.standard.string(forKey: "team_department") ?? "Acil Tıp Kliniği" {
        didSet { UserDefaults.standard.set(teamDepartment, forKey: "team_department") }
    }

    var inviteCode: String = {
        if let c = UserDefaults.standard.string(forKey: "invite_code") { return c }
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code  = "NBT-" + String((0..<4).map { _ in chars.randomElement()! })
        UserDefaults.standard.set(code, forKey: "invite_code")
        return code
    }() {
        didSet { UserDefaults.standard.set(inviteCode, forKey: "invite_code") }
    }

    func regenerateInviteCode(ctx: ModelContext) -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        let code  = "NBT-" + String((0..<4).map { _ in chars.randomElement()! })
        inviteCode = code
        ctx.insert(AuditEntry(message: "Ekip davet kodu yenilendi: \(code)"))
        return code
    }

    func createNewTeam(name: String, department: String, ctx: ModelContext) {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedDept = department.trimmingCharacters(in: .whitespaces)
        teamName = trimmedName.isEmpty ? "Acil Servis Nöbet Ekibi" : trimmedName
        teamDepartment = trimmedDept.isEmpty ? "Acil Tıp Kliniği" : trimmedDept
        _ = regenerateInviteCode(ctx: ctx)
        ctx.insert(AuditEntry(message: "Yeni ekip oluşturuldu: \(teamName) - \(teamDepartment)"))
    }

    func joinTeamWithCode(code: String, userName: String, userRole: UserRole, ctx: ModelContext) -> Bool {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanCode.isEmpty else { return false }
        
        let formatted = cleanCode.hasPrefix("NBT-") ? cleanCode : "NBT-\(cleanCode)"
        inviteCode = formatted
        
        let trimmedName = userName.trimmingCharacters(in: .whitespaces)
        let finalName = trimmedName.isEmpty ? (userEmail.isEmpty ? "Dr. Hekim" : userEmail) : trimmedName
        
        // Add member to team if not already added
        let descriptor = FetchDescriptor<TeamMember>()
        let existing = (try? ctx.fetch(descriptor)) ?? []
        if !existing.contains(where: { $0.name.lowercased() == finalName.lowercased() }) {
            let newMember = TeamMember(name: finalName, role: userRole)
            ctx.insert(newMember)
        }
        
        ctx.insert(AuditEntry(message: "\(finalName) (\(userRole.label)), \(formatted) davet koduyla \(teamName) ekibine katıldı"))
        try? ctx.save()
        return true
    }

    func leaveTeam(ctx: ModelContext) {
        let oldTeam = teamName
        let userName = userEmail.isEmpty ? "Kullanıcı" : userEmail

        // Remove user from TeamMember table
        let descriptor = FetchDescriptor<TeamMember>()
        if let members = try? ctx.fetch(descriptor) {
            for member in members where member.name.lowercased() == userName.lowercased() {
                ctx.delete(member)
            }
        }

        teamName = "Ekip Yok (Bağlantısız)"
        teamDepartment = "Klinik Seçilmedi"
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        inviteCode = "NBT-" + String((0..<4).map { _ in chars.randomElement()! })

        ctx.insert(AuditEntry(message: "\(userName), \(oldTeam) ekibinden ayrıldı"))
        try? ctx.save()
    }


    // MARK: Security & Biometrics
    var isBiometricsEnabled: Bool = UserDefaults.standard.bool(forKey: "biometrics_enabled") {
        didSet { UserDefaults.standard.set(isBiometricsEnabled, forKey: "biometrics_enabled") }
    }

    var isUnlocked: Bool = true

    // MARK: Duty Days
    var dutyDays: Set<Int> = {
        let arr = UserDefaults.standard.array(forKey: "duty_days") as? [Int] ?? [0, 3]
        return Set(arr)
    }() {
        didSet {
            UserDefaults.standard.set(Array(dutyDays), forKey: "duty_days")
        }
    }

    func toggleDutyDay(_ dayIndex: Int) {
        if dutyDays.contains(dayIndex) {
            dutyDays.remove(dayIndex)
        } else {
            dutyDays.insert(dayIndex)
        }
    }

    // MARK: Navigation
    var currentTab: AppTab = .pano
    var selectedPatientID: UUID? = nil

    // MARK: Sheet routing
    var showAddPatient     = false
    var showPrepareSheet   = false
    var showReceiveSheet   = false

    // MARK: Handover
    var handover = HandoverState()

    // MARK: Actions

    func login(email: String, role: UserRole) {
        userEmail  = email.trimmingCharacters(in: .whitespaces)
        userRole   = role
        isLoggedIn = true
    }

    func logout() {
        isLoggedIn = false
    }

    func resetHandover() {
        handover.reset()
    }

    // MARK: - Biometrics Authentication

    func authenticateBiometrics() {
        guard isBiometricsEnabled else {
            isUnlocked = true
            return
        }
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Nöbet Devir klinik verilerine erişmek için doğrulama yapın.") { success, _ in
                DispatchQueue.main.async {
                    self.isUnlocked = success
                }
            }
        } else {
            isUnlocked = true
        }
    }

    // MARK: - Retention Auto-Cleanup

    func performRetentionCleanup(ctx: ModelContext) {
        guard handover.status == .acknowledged, let sentAt = handover.sentAt else { return }
        let hoursPassed = Date().timeIntervalSince(sentAt) / 3600.0
        if hoursPassed >= Double(retentionHours) {
            do {
                let descriptor = FetchDescriptor<Patient>()
                let patients = try ctx.fetch(descriptor)
                for p in patients {
                    ctx.delete(p)
                }
                handover.reset()
                ctx.insert(AuditEntry(message: "Otomatik silme: \(retentionHours) saatlik saklama süresi doldu, nöbet verileri temizlendi."))
                try ctx.save()
            } catch {
                print("Retention cleanup error: \(error)")
            }
        }
    }

    // MARK: - Seed Realistic Clinical Demo Data (Idempotent & Deduplicated)

    @discardableResult
    func seedInitialData(ctx: ModelContext) -> (patientsAdded: Int, membersAdded: Int) {
        // First deduplicate any existing clones in the database
        deduplicateExistingData(ctx: ctx)

        let descriptor = FetchDescriptor<Patient>()
        let existingPatients = (try? ctx.fetch(descriptor)) ?? []
        let existingBeds = Set(existingPatients.map { $0.bed.trimmingCharacters(in: .whitespaces).uppercased() })

        let memberDesc = FetchDescriptor<TeamMember>()
        let existingMembers = (try? ctx.fetch(memberDesc)) ?? []
        let existingNames = Set(existingMembers.map { $0.name.trimmingCharacters(in: .whitespaces).lowercased() })

        var patientsAdded = 0
        var membersAdded = 0

        // P1: B2
        if !existingBeds.contains("B2") {
            let p1 = Patient(bed: "B2", age: 52, sex: .erkek,
                             problem: "Göğüs ağrısı, ilk troponin negatif",
                             severity: .unstable)
            p1.summary = "Tipik retrosternal baskı tarzı göğüs ağrısı. EKG'de dinamik ST-T değişikliği izlenmedi. Vital bulgular stabil."
            p1.contingency = "Ağrı tekrarlarsa dilaltı nitrogliserin ver, 2. saat EKG ve troponin kontrol et; kardiyoloji kıdemlisine danış."
            let t1 = PatientTask(text: "2. saat kontrol troponin kanı al")
            let t2 = PatientTask(text: "Kardiyoloji konsültasyonunu takip et")
            let tm1 = PatientTimer(text: "Kontrol troponin ve EKG", due: Date().addingTimeInterval(35 * 60))
            p1.tasks = [t1, t2]
            p1.timers = [tm1]
            ctx.insert(p1)
            ctx.insert(t1)
            ctx.insert(t2)
            ctx.insert(tm1)
            patientsAdded += 1
        }

        // P2: A4
        if !existingBeds.contains("A4") {
            let p2 = Patient(bed: "A4", age: 71, sex: .kadin,
                             problem: "Toplum kökenli pnömoni, ateş ve dispne",
                             severity: .watch)
            p2.summary = "Sağ bazalde krepitan ral (+). SpO2 oda havasında %91, 2L/dk nazal kanülle %96. CURB-65 skoru: 2 (orta risk)."
            p2.contingency = "Oksijen ihtiyacı artarsa veya takipne >30 olursa kan gazı bakıp göğüs hastalıklarına devret."
            let t3 = PatientTask(text: "Antibiyotik infüzyonunu başlat (Seftriakson + Azitromisin)")
            let tm2 = PatientTimer(text: "Vital bulgu ve SpO2 kontrolü", due: Date().addingTimeInterval(60 * 60))
            p2.tasks = [t3]
            p2.timers = [tm2]
            ctx.insert(p2)
            ctx.insert(t3)
            ctx.insert(tm2)
            patientsAdded += 1
        }

        // P3: C1
        if !existingBeds.contains("C1") {
            let p3 = Patient(bed: "C1", age: 28, sex: .erkek,
                             problem: "Akut apandisit şüphesi, sağ alt kadran hassasiyeti",
                             severity: .stable)
            p3.summary = "Bulantı ve sağ alt kadranda lokalize rebound (+). Lökositoz: 14.200. Batın USG sonucu bekleniyor."
            p3.contingency = "Akut batın bulguları belirginleşirse acil genel cerrahi konsültasyonu iste."
            let t4 = PatientTask(text: "Batın USG raporunu kontrol et")
            p3.tasks = [t4]
            ctx.insert(p3)
            ctx.insert(t4)
            patientsAdded += 1
        }

        // Default team members deduplication
        let defaultMembers: [(name: String, role: UserRole)] = [
            ("Dr. Selin Kaya", .uzman),
            ("Dr. Burak Demir", .asistan),
            ("Dr. Elif Yılmaz", .pratisyen)
        ]

        for m in defaultMembers {
            if !existingNames.contains(m.name.lowercased()) {
                let member = TeamMember(name: m.name, role: m.role)
                ctx.insert(member)
                membersAdded += 1
            }
        }

        if patientsAdded > 0 || membersAdded > 0 {
            ctx.insert(AuditEntry(message: "Örnek demo veriler yüklendi (\(patientsAdded) hasta, \(membersAdded) ekip üyesi)"))
            try? ctx.save()
        }

        return (patientsAdded, membersAdded)
    }

    /// Automatically finds and removes duplicate clone patients with the same bed number
    func deduplicateExistingData(ctx: ModelContext) {
        let descriptor = FetchDescriptor<Patient>()
        guard let patients = try? ctx.fetch(descriptor) else { return }

        var seenBeds = Set<String>()
        var duplicatesRemoved = 0

        for patient in patients {
            let bedKey = patient.bed.trimmingCharacters(in: .whitespaces).uppercased()
            if seenBeds.contains(bedKey) {
                // Delete timers & notifications for duplicate
                for timer in patient.timers {
                    NotificationManager.shared.cancel(notificationID: timer.notificationID)
                }
                ctx.delete(patient)
                duplicatesRemoved += 1
            } else {
                seenBeds.insert(bedKey)
            }
        }

        // Deduplicate team members
        let memberDesc = FetchDescriptor<TeamMember>()
        if let members = try? ctx.fetch(memberDesc) {
            var seenNames = Set<String>()
            for member in members {
                let nameKey = member.name.trimmingCharacters(in: .whitespaces).lowercased()
                if seenNames.contains(nameKey) {
                    ctx.delete(member)
                } else {
                    seenNames.insert(nameKey)
                }
            }
        }

        if duplicatesRemoved > 0 {
            ctx.insert(AuditEntry(message: "Mükerrer/klon kayıtlar temizlendi (\(duplicatesRemoved) kopya)"))
            try? ctx.save()
        }
    }
}
