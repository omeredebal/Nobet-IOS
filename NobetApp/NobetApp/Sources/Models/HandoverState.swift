import Foundation
import Observation

// MARK: - Handover Status

enum HandoverStatus: String, Codable {
    case draft
    case sent
    case acknowledged
}

// MARK: - Handover State (UserDefaults-backed)

@Observable
final class HandoverState {

    private enum Keys {
        static let status   = "handover_status"
        static let toName   = "handover_to"
        static let ackTime  = "handover_ack_time"
        static let sentAt   = "handover_sent_at"
    }

    var status: HandoverStatus = {
        HandoverStatus(rawValue: UserDefaults.standard.string(forKey: Keys.status) ?? "") ?? .draft
    }() {
        didSet { UserDefaults.standard.set(status.rawValue, forKey: Keys.status) }
    }

    var toName: String = {
        UserDefaults.standard.string(forKey: Keys.toName) ?? ""
    }() {
        didSet { UserDefaults.standard.set(toName, forKey: Keys.toName) }
    }

    var ackTime: String? = {
        UserDefaults.standard.string(forKey: Keys.ackTime)
    }() {
        didSet { UserDefaults.standard.set(ackTime, forKey: Keys.ackTime) }
    }

    var sentAt: Date? = {
        let t = UserDefaults.standard.double(forKey: Keys.sentAt)
        return t == 0 ? nil : Date(timeIntervalSince1970: t)
    }() {
        didSet {
            UserDefaults.standard.set(sentAt?.timeIntervalSince1970 ?? 0, forKey: Keys.sentAt)
        }
    }

    func send(to name: String) {
        toName = name
        status = .sent
        sentAt = Date()
    }

    func acknowledge() {
        status = .acknowledged
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        ackTime = fmt.string(from: Date())
    }

    func reset() {
        status  = .draft
        toName  = ""
        ackTime = nil
        sentAt  = nil
    }
}
