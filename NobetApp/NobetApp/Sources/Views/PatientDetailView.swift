import SwiftUI
import SwiftData

struct PatientDetailView: View {
    @Bindable var patient: Patient
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    @State private var newTaskText   = ""
    @State private var newTimerText  = ""
    @State private var tick          = Date()
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Patient Overview Card
                Section_Overview

                // I — Illness Severity
                Section_I

                // P — Patient Summary
                Section_P

                // A — Action List
                Section_A

                // S — Situation Awareness & Contingency
                Section_S

                // Timers
                Section_Timers

                // Discharge / Delete Action
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Hastayı Devirden Çıkar / Taburcu Et", systemImage: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.severityFG(.unstable))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color.severityBG(.unstable))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.severityBorder(.unstable), lineWidth: 0.5)
                        )
                }
                .padding(.top, 6)
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Yatak \(patient.bed)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    SeverityPill(severity: patient.severity, small: true)

                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Bilgileri Düzenle", systemImage: "pencil")
                        }

                        Button {
                            copyPatientSummary()
                        } label: {
                            Label("Devir Notunu Kopyala", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Hastayı Devirden Çıkar", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.brand)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditPatientSheet(patient: patient)
        }
        .alert("Hastayı Devirden Çıkar", isPresented: $showDeleteAlert) {
            Button("Taburcu Et / Sil", role: .destructive) {
                deletePatient()
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("\(patient.bed) yataklı hasta listeden ve nöbet devrinden kalıcı olarak silinecektir.")
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in tick = Date() }
    }

    // MARK: — Overview

    private var Section_Overview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // Sleek Bed token
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.severityBG(patient.severity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.severityBorder(patient.severity), lineWidth: 0.5)
                        )

                    VStack(spacing: 1) {
                        Text("YATAK")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.severityFG(patient.severity).opacity(0.75))
                            .kerning(0.6)
                        Text(patient.bed)
                            .font(AppFont.mono(18, weight: .bold))
                            .foregroundStyle(Color.severityFG(patient.severity))
                    }
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: patient.sex == .erkek ? "figure.male" : "figure.female")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("\(patient.age) Yaş · \(patient.sex == .erkek ? "Erkek" : "Kadın")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(patient.problem)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brand)
                        .padding(8)
                        .background(Color.brand.opacity(0.08))
                        .clipShape(Circle())
                }
            }
        }
        .padding(16)
        .card()
    }

    // MARK: — I: Illness Severity

    private var Section_I: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPASSHeader(letter: "I", title: "Hastalık şiddeti")
            SeverityPicker(selection: Binding(
                get: { patient.severity },
                set: { newVal in
                    patient.severity = newVal
                    audit("\(patient.bed) şiddet: \(newVal.label)")
                    haptic()
                }
            ))
        }
        .padding(16)
        .card()
    }

    // MARK: — P: Patient Summary

    private var Section_P: some View {
        VStack(alignment: .leading, spacing: 10) {
            IPASSHeader(letter: "P", title: "Hasta özeti")
            ZStack(alignment: .topLeading) {
                if patient.summary.isEmpty {
                    Text("Klinik tablo, anamnez ve laboratuvar özetini buraya girin...")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $patient.summary)
                    .frame(minHeight: 90)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
        }
        .padding(16)
        .card()
    }

    // MARK: — A: Action List

    private var Section_A: some View {
        VStack(alignment: .leading, spacing: 12) {
            IPASSHeader(letter: "A", title: "Yapılacaklar")

            if patient.sortedTasks.isEmpty {
                Text("Henüz görev eklenmedi.")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 2)
            } else {
                VStack(spacing: 8) {
                    ForEach(patient.sortedTasks, id: \.id) { task in
                        TaskRow(task: task) {
                            task.isDone.toggle()
                            audit("\(patient.bed) görev \(task.isDone ? "tamamlandı" : "açıldı"): \(task.text)")
                            hapticSelection()
                        }
                    }
                }
            }

            // Add task input bar
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.brand)

                TextField("Yeni klinik görev ekle...", text: $newTaskText)
                    .font(.system(size: 14))
                    .submitLabel(.done)
                    .onSubmit(addTask)

                if !newTaskText.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: addTask) {
                        Text("Ekle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.brand)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )
            .padding(.top, 4)
        }
        .padding(16)
        .card()
    }

    private func addTask() {
        let text = newTaskText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let t = PatientTask(text: text)
        patient.tasks.append(t)
        ctx.insert(t)
        audit("\(patient.bed) görev eklendi: \(text)")
        haptic()
        newTaskText = ""
    }

    // MARK: — S: Situation Awareness & Contingency

    private var Section_S: some View {
        VStack(alignment: .leading, spacing: 10) {
            IPASSHeader(letter: "S", title: "Olası Durumlar ve Plan")

            ZStack(alignment: .topLeading) {
                if patient.contingency.isEmpty {
                    Text("Klinik kötüleşme veya acil durumda ne yapılacak? İlave konsültasyon veya ilaç planını girin...")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                }
                TextEditor(text: $patient.contingency)
                    .frame(minHeight: 80)
                    .font(.system(size: 14))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
            )

            if patient.severity == .unstable && patient.contingency.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                    Text("Kararsız hasta için acil durum planı zorunludur.")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.severityFG(.unstable))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.severityBG(.unstable))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.severityBorder(.unstable), lineWidth: 0.5)
                )
            }
        }
        .padding(16)
        .card()
    }

    // MARK: — Timers

    private var Section_Timers: some View {
        VStack(alignment: .leading, spacing: 12) {
            EyebrowLabel(text: "Hatırlatıcılar")

            if patient.sortedTimers.isEmpty {
                Text("Hatırlatıcı yok.")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(patient.sortedTimers, id: \.id) { timer in
                    TimerRow(timer: timer, tick: tick,
                             onSnooze: { snooze(timer) },
                             onDone:   { deleteTimer(timer) })
                    if timer.id != patient.sortedTimers.last?.id {
                        Divider()
                    }
                }
            }

            Divider().padding(.vertical, 4)

            // Add timer
            VStack(alignment: .leading, spacing: 10) {
                TextField("Hatırlatma sebebi (örn. Kontrol EKG, Kan gazı)", text: $newTimerText)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                    )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([15, 30, 60, 120, 240], id: \.self) { mins in
                            Button {
                                addTimer(minutes: mins)
                            } label: {
                                Text(mins < 60 ? "+\(mins) dk" : "+\(mins/60) sa")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Color.brand.opacity(0.10))
                                    .foregroundStyle(Color.brand)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(16)
        .card()
    }

    private func addTimer(minutes: Int) {
        let text = newTimerText.trimmingCharacters(in: .whitespaces)
        let label = text.isEmpty ? "Yeniden değerlendir" : text
        let due   = Date().addingTimeInterval(Double(minutes) * 60)
        let t     = PatientTimer(text: label, due: due)
        patient.timers.append(t)
        ctx.insert(t)
        NotificationManager.shared.schedule(timer: t, patientBed: patient.bed)
        audit("\(patient.bed) hatırlatıcı kuruldu: \(label)")
        haptic()
        newTimerText = ""
    }

    private func snooze(_ timer: PatientTimer) {
        timer.due = max(timer.due, Date()).addingTimeInterval(30 * 60)
        NotificationManager.shared.snooze(timer: timer, patientBed: patient.bed)
        audit("\(patient.bed) hatırlatıcı ertelendi: \(timer.text)")
        haptic()
    }

    private func deleteTimer(_ timer: PatientTimer) {
        NotificationManager.shared.cancel(notificationID: timer.notificationID)
        patient.timers.removeAll { $0.id == timer.id }
        ctx.delete(timer)
        audit("\(patient.bed) hatırlatıcı tamamlandı: \(timer.text)")
        haptic()
    }

    private func audit(_ msg: String) {
        ctx.insert(AuditEntry(message: msg))
    }

    private func copyPatientSummary() {
        var lines: [String] = []
        lines.append("Yatak \(patient.bed) · \(patient.age) \(patient.sex.rawValue) [\(patient.severity.label)]")
        lines.append("Sorun: \(patient.problem)")
        if !patient.summary.isEmpty {
            lines.append("Özet: \(patient.summary)")
        }
        let openTasks = patient.tasks.filter { !$0.isDone }
        if !openTasks.isEmpty {
            lines.append("Yapılacaklar: " + openTasks.map { "• " + $0.text }.joined(separator: ", "))
        }
        if !patient.contingency.isEmpty {
            lines.append("Olası Durum: \(patient.contingency)")
        }
        UIPasteboard.general.string = lines.joined(separator: "\n")
        hapticNotification(.success)
    }

    private func deletePatient() {
        for timer in patient.timers {
            NotificationManager.shared.cancel(notificationID: timer.notificationID)
        }
        let bedName = patient.bed
        ctx.delete(patient)
        audit("\(bedName) hastası devirden çıkarıldı / taburcu edildi")
        hapticNotification(.success)
        dismiss()
    }
}

// MARK: - Edit Patient Sheet

struct EditPatientSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var patient: Patient

    @Query private var existingPatients: [Patient]

    @State private var bed: String = ""
    @State private var age: String = ""
    @State private var sex: Sex = .erkek
    @State private var problem: String = ""
    @State private var errorMsg: String = ""

    private func containsPII(_ s: String) -> Bool {
        let pattern = "\\d{9,}"
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    private func save() {
        let trimmedBed = bed.trimmingCharacters(in: .whitespaces).uppercased()
        let trimmedProb = problem.trimmingCharacters(in: .whitespaces)
        guard !trimmedBed.isEmpty, !trimmedProb.isEmpty, let ageInt = Int(age), ageInt > 0 else {
            errorMsg = "Yatak, yaş ve sorun zorunludur."
            hapticNotification(.error)
            return
        }
        if existingPatients.contains(where: { $0.id != patient.id && $0.bed.uppercased() == trimmedBed }) {
            errorMsg = "\(trimmedBed) numaralı yatakta zaten başka bir hasta kayıtlı."
            hapticNotification(.error)
            return
        }
        if containsPII(trimmedBed + trimmedProb + patient.summary) {
            errorMsg = "Metinde kimlik numarası benzeri ifade tespit edildi."
            hapticNotification(.error)
            return
        }

        patient.bed = trimmedBed
        patient.age = ageInt
        patient.sex = sex
        patient.problem = trimmedProb
        ctx.insert(AuditEntry(message: "\(patient.bed) bilgileri güncellendi"))
        hapticNotification(.success)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            Form {
                if !errorMsg.isEmpty {
                    Section {
                        Text(errorMsg)
                            .foregroundStyle(Color.severityFG(.unstable))
                            .font(.system(size: 13, weight: .medium))
                    }
                }

                Section("Demografik Bilgiler") {
                    TextField("Yatak / Oda", text: $bed)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                    TextField("Yaş", text: $age)
                        .keyboardType(.numberPad)
                    Picker("Cinsiyet", selection: $sex) {
                        ForEach(Sex.allCases, id: \.self) { s in
                            Text(s == .erkek ? "Erkek" : "Kadın").tag(s)
                        }
                    }
                }

                Section("Ana Sorun / Ön Tanı") {
                    TextField("Klinik tablo veya ana şikayet", text: $problem, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Bilgileri Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                }
            }
            .onAppear {
                bed = patient.bed
                age = "\(patient.age)"
                sex = patient.sex
                problem = patient.problem
            }
        }
    }
}


// MARK: - Task Row

private struct TaskRow: View {
    @Bindable var task: PatientTask
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(task.isDone ? Color.brand : Color(.systemGray3))
                    .frame(width: 22)

                Text(task.text)
                    .font(.system(size: 14, weight: task.isDone ? .regular : .medium))
                    .foregroundStyle(task.isDone ? .secondary : .primary)
                    .strikethrough(task.isDone)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Timer Row

private struct TimerRow: View {
    @Bindable var timer: PatientTimer
    let tick: Date
    let onSnooze: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timer.text)
                    .font(.system(size: 14, weight: .medium))
                Text(timer.durationText(from: tick))
                    .font(AppFont.mono(12, weight: .semibold))
                    .foregroundStyle(timer.isLate ? Color.severityFG(.unstable) : Color.brand)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Button("+30 dk", action: onSnooze)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))

                Button("Bitti", action: onDone)
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }
}
