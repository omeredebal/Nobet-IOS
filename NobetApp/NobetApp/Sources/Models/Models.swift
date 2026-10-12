import Foundation
import SwiftData

// MARK: - Enums

enum Severity: String, Codable, CaseIterable, Hashable {
    case unstable = "unstable"
    case watch    = "watch"
    case stable   = "stable"

    var label: String {
        switch self {
        case .unstable: "Kararsız"
        case .watch:    "İzlemde"
        case .stable:   "Stabil"
        }
    }

    var sortOrder: Int {
        switch self {
        case .unstable: 0
        case .watch:    1
        case .stable:   2
        }
    }

    var systemImage: String {
        switch self {
        case .unstable: "exclamationmark.triangle.fill"
        case .watch:    "eye.fill"
        case .stable:   "checkmark.circle.fill"
        }
    }
}

enum UserRole: String, Codable, CaseIterable, Hashable {
    case uzman     = "Uzman"
    case asistan   = "Asistan"
    case pratisyen = "Pratisyen"
    case intern_   = "İntörn"
    case ogrenci   = "Tıp öğrencisi"

    var label: String { rawValue }
    var isPhysician: Bool {
        self == .uzman || self == .asistan || self == .pratisyen
    }
}

enum Sex: String, Codable, CaseIterable {
    case erkek = "E"
    case kadin = "K"
}

enum AppTab: String, Hashable {
    case pano, skorlar, ekip, profil
}

// MARK: - SwiftData: Patient

@Model
final class Patient: Identifiable {
    @Attribute(.unique) var id: UUID
    var bed: String
    var age: Int
    var sexRaw: String
    var problem: String
    var severityRaw: String
    var summary: String
    var contingency: String
    var acknowledged: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PatientTask.patient)
    var tasks: [PatientTask] = []

    @Relationship(deleteRule: .cascade, inverse: \PatientTimer.patient)
    var timers: [PatientTimer] = []

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .erkek }
        set { sexRaw = newValue.rawValue }
    }

    var severity: Severity {
        get { Severity(rawValue: severityRaw) ?? .stable }
        set { severityRaw = newValue.rawValue }
    }

    var openTaskCount: Int { tasks.filter { !$0.isDone }.count }

    var nextTimer: PatientTimer? {
        timers.min(by: { $0.due < $1.due })
    }

    var sortedTimers: [PatientTimer] {
        timers.sorted { $0.due < $1.due }
    }

    var sortedTasks: [PatientTask] {
        tasks.sorted {
            if $0.isDone != $1.isDone {
                return !$0.isDone && $1.isDone
            }
            return $0.createdAt < $1.createdAt
        }
    }

    init(bed: String, age: Int, sex: Sex = .erkek,
         problem: String, severity: Severity = .stable) {
        self.id           = UUID()
        self.bed          = bed.uppercased()
        self.age          = age
        self.sexRaw       = sex.rawValue
        self.problem      = problem
        self.severityRaw  = severity.rawValue
        self.summary      = ""
        self.contingency  = ""
        self.acknowledged = false
        self.createdAt    = Date()
    }
}

// MARK: - SwiftData: PatientTask

@Model
final class PatientTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var isDone: Bool
    var createdAt: Date
    var patient: Patient?

    init(text: String) {
        self.id        = UUID()
        self.text      = text
        self.isDone    = false
        self.createdAt = Date()
    }
}

// MARK: - SwiftData: PatientTimer

@Model
final class PatientTimer: Identifiable {
    @Attribute(.unique) var id: UUID
    var text: String
    var due: Date
    var notificationID: String
    var patient: Patient?

    var isLate: Bool { due < Date() }

    func durationText(from now: Date = Date()) -> String {
        let diff = due.timeIntervalSince(now)
        let mins = Int(abs(diff) / 60)
        let late = diff < 0
        let h = mins / 60, m = mins % 60
        var parts: [String] = []
        if h > 0 { parts.append("\(h) sa") }
        if m > 0 || h == 0 { parts.append("\(m) dk") }
        let base = parts.joined(separator: " ")
        return late ? "\(base) gecikti" : "\(base) sonra"
    }

    init(text: String, due: Date) {
        self.id             = UUID()
        self.text           = text
        self.due            = due
        self.notificationID = UUID().uuidString
    }
}

// MARK: - SwiftData: TeamMember

@Model
final class TeamMember: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var roleRaw: String
    var joinedAt: Date

    var role: UserRole {
        get { UserRole(rawValue: roleRaw) ?? .asistan }
        set { roleRaw = newValue.rawValue }
    }

    init(name: String, role: UserRole) {
        self.id       = UUID()
        self.name     = name
        self.roleRaw  = role.rawValue
        self.joinedAt = Date()
    }
}

// MARK: - SwiftData: AuditEntry

@Model
final class AuditEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var message: String

    init(message: String) {
        self.id        = UUID()
        self.timestamp = Date()
        self.message   = message
    }
}
