import SwiftUI
import SwiftData

@main
struct NobetApp: App {

    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
        .modelContainer(for: [
            Patient.self,
            PatientTask.self,
            PatientTimer.self,
            TeamMember.self,
            AuditEntry.self
        ])
    }
}
