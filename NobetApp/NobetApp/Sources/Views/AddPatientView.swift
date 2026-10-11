import SwiftUI
import SwiftData

struct AddPatientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(AppStore.self) private var store

    @State private var bed       = ""
    @State private var age       = ""
    @State private var sex: Sex  = .erkek
    @State private var problem   = ""
    @State private var severity: Severity = .stable
    @State private var summary   = ""
    @State private var errorMsg  = ""

    // Simple PII detection
    private func containsPII(_ s: String) -> Bool {
        let pattern = "\\d{9,}"   // long digit runs suggest TC / protocol numbers
        let range = s.range(of: pattern, options: .regularExpression)
        return range != nil
    }

    private func save() {
        errorMsg = ""
        let bedTrimmed = bed.trimmingCharacters(in: .whitespaces)
        let probTrimmed = problem.trimmingCharacters(in: .whitespaces)
        guard !bedTrimmed.isEmpty, !probTrimmed.isEmpty, let ageInt = Int(age), ageInt > 0 else {
            errorMsg = "Yatak numarası, yaş ve ana sorun zorunludur."
            hapticNotification(.error)
            return
        }
        let combined = bedTrimmed + probTrimmed + summary
        if containsPII(combined) {
            errorMsg = "Metinde kimlik numarası gibi bir ifade var. Kaldırıp tekrar deneyin."
            hapticNotification(.error)
            return
        }

        let patient          = Patient(bed: bedTrimmed, age: ageInt, sex: sex, problem: probTrimmed, severity: severity)
        patient.summary      = summary.trimmingCharacters(in: .whitespaces)
        ctx.insert(patient)

        // Audit
        let entry = AuditEntry(message: "\(patient.bed) kartı oluşturuldu")
        ctx.insert(entry)

        hapticNotification(.success)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Privacy banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.orange)
                        Text("Ad, soyad, TC kimlik veya protokol numarası girmeyin. Yalnızca yatak/oda numarası kullanın.")
                            .font(.system(size: 13))
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Error
                    if !errorMsg.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                            Text(errorMsg)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.severityFG(.unstable))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.severityBG(.unstable))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Bed / Age / Sex row
                    HStack(spacing: 10) {
                        LabeledField(label: "Yatak / oda") {
                            TextField("Örn. B2", text: $bed)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                        }
                        .frame(maxWidth: 90)

                        LabeledField(label: "Yaş") {
                            TextField("52", text: $age)
                                .keyboardType(.numberPad)
                        }
                        .frame(maxWidth: 70)

                        LabeledField(label: "Cinsiyet") {
                            Picker("", selection: $sex) {
                                ForEach(Sex.allCases, id: \.self) { s in
                                    Text(s.rawValue).tag(s)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    // Problem
                    LabeledField(label: "Ana sorun") {
                        TextField("Örn. Göğüs ağrısı, ilk troponin negatif", text: $problem, axis: .vertical)
                            .lineLimit(2...4)
                            .autocorrectionDisabled()
                    }

                    // Severity
                    VStack(alignment: .leading, spacing: 8) {
                        EyebrowLabel(text: "Hastalık şiddeti")
                        SeverityPicker(selection: $severity)
                    }

                    // Summary
                    LabeledField(label: "Klinik özet (isteğe bağlı)") {
                        TextField("Kısa klinik özet", text: $summary, axis: .vertical)
                            .lineLimit(3...6)
                            .autocorrectionDisabled()
                    }

                    // Save
                    Button(action: save) {
                        Text("Kartı kaydet")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.teal)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Yeni Hasta Kartı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

// MARK: - Labeled Field Helper

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
                )
        }
    }
}
