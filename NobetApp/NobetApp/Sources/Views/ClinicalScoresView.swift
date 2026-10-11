import SwiftUI

struct ClinicalScoresView: View {

    @State private var qsofa  = QSOFAState()
    @State private var curb65 = CURB65State()
    @State private var gcs    = GCSState()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    qsofaSection
                    curb65Section
                    gcsSection

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                        Text("Klinik karar destek aracıdır, tıbbi cihaz değildir. Karar ve sorumluluk hekime aittir.")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 20)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Klinik Skorlar")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: — qSOFA

    private var qsofaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("qSOFA").font(.system(size: 20, weight: .bold))
            Text("Kaynak: Seymour ve ark., JAMA 2016 (Sepsis-3)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            CheckRow(label: "Solunum sayısı ≥ 22/dk",
                     checked: $qsofa.respiratoryRate)
            CheckRow(label: "Mental durumda bozulma",
                     checked: $qsofa.mentalStatus)
            CheckRow(label: "Sistolik kan basıncı ≤ 100 mmHg",
                     checked: $qsofa.systolicBP)

            ScoreResult(
                score: qsofa.total,
                max: 3,
                severity: qsofa.total >= 2 ? .unstable : .stable,
                interpretation: qsofa.interpretation
            )
        }
        .padding(16)
        .card()
    }

    // MARK: — CURB-65

    private var curb65Section: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CURB-65").font(.system(size: 20, weight: .bold))
            Text("Kaynak: Lim ve ark., Thorax 2003")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            CheckRow(label: "Konfüzyon",                              checked: $curb65.confusion)
            CheckRow(label: "Üre > 7 mmol/L (BUN > 19 mg/dL)",       checked: $curb65.urea)
            CheckRow(label: "Solunum sayısı ≥ 30/dk",                 checked: $curb65.respiratoryRate)
            CheckRow(label: "Sistolik < 90 veya diastolik ≤ 60 mmHg", checked: $curb65.bloodPressure)
            CheckRow(label: "Yaş ≥ 65",                               checked: $curb65.age65)

            ScoreResult(
                score: curb65.total,
                max: 5,
                severity: curb65.severity,
                interpretation: curb65.interpretation
            )
        }
        .padding(16)
        .card()
    }

    // MARK: — GCS

    private var gcsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Glasgow Koma Skalası").font(.system(size: 20, weight: .bold))
            Text("Kaynak: Teasdale ve Jennett, Lancet 1974")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            GCSPicker(label: "Göz açma", selection: $gcs.eye,
                      options: [(4,"Spontan"), (3,"Sözel uyarana"),
                                (2,"Ağrılı uyarana"), (1,"Yok")])

            GCSPicker(label: "Sözel yanıt", selection: $gcs.verbal,
                      options: [(5,"Oryante"), (4,"Konfüze"),
                                (3,"Uygunsuz kelimeler"), (2,"Anlamsız sesler"), (1,"Yok")])

            GCSPicker(label: "Motor yanıt", selection: $gcs.motor,
                      options: [(6,"Emre uyar"), (5,"Ağrıyı lokalize eder"),
                                (4,"Ağrıdan çekilir"), (3,"Fleksiyon"),
                                (2,"Ekstansiyon"), (1,"Yok")])

            ScoreResult(
                score: gcs.total,
                max: 15,
                severity: gcs.severity,
                interpretation: gcs.interpretation
            )
        }
        .padding(16)
        .card()
    }
}

// MARK: - State Models (local, no persistence needed)

private struct QSOFAState {
    var respiratoryRate = false
    var mentalStatus    = false
    var systolicBP      = false
    var total: Int { [respiratoryRate, mentalStatus, systolicBP].filter { $0 }.count }
    var interpretation: String {
        total >= 2
        ? "Yüksek risk: sepsis ve kötü sonlanım olasılığı artmış."
        : "Düşük risk. Klinik tablo yine de değerlendirilmeli."
    }
}

private struct CURB65State {
    var confusion       = false
    var urea            = false
    var respiratoryRate = false
    var bloodPressure   = false
    var age65           = false
    var total: Int { [confusion, urea, respiratoryRate, bloodPressure, age65].filter { $0 }.count }
    var severity: Severity {
        switch total {
        case 0...1: .stable
        case 2:     .watch
        default:    .unstable
        }
    }
    var interpretation: String {
        switch total {
        case 0...1: "Düşük risk. Ayaktan tedavi düşünülebilir."
        case 2:     "Orta risk. Yatış düşünülmeli."
        default:    "Yüksek risk. Yoğun bakım değerlendirmesi düşünülmeli."
        }
    }
}

private struct GCSState {
    var eye    = 4
    var verbal = 5
    var motor  = 6
    var total: Int { eye + verbal + motor }
    var severity: Severity {
        switch total {
        case 13...15: .stable
        case 9...12:  .watch
        default:      .unstable
        }
    }
    var interpretation: String {
        switch total {
        case 13...15: "Hafif bozulma (13–15)."
        case 9...12:  "Orta bozulma (9–12)."
        default:      "Ağır bozulma (8 ve altı)."
        }
    }
}

// MARK: - UI Components

private struct CheckRow: View {
    let label: String
    @Binding var checked: Bool

    var body: some View {
        Button {
            checked.toggle()
            haptic()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(checked ? Color.teal : .secondary)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct GCSPicker: View {
    let label: String
    @Binding var selection: Int
    let options: [(Int, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Picker(label, selection: $selection) {
                ForEach(options, id: \.0) { val, desc in
                    Text("\(val) · \(desc)").tag(val)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}

private struct ScoreResult: View {
    let score: Int
    let max: Int
    let severity: Severity
    let interpretation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(score)")
                    .font(AppFont.mono(36, weight: .bold))
                    .foregroundStyle(Color.severityColor(severity))

                Text("/ \(max)")
                    .font(AppFont.mono(16, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                SeverityPill(severity: severity, small: true)
            }

            Text(interpretation)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.severityBG(severity))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.severityBorder(severity), lineWidth: 1)
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: score)
    }
}
