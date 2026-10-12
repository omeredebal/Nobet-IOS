import SwiftUI

struct LoginView: View {
    @Environment(AppStore.self) private var store

    @State private var email = "Dr. Ömer"
    @State private var role: UserRole = .asistan
    @State private var shake = false
    @State private var showJoinSheet = false

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Header
                    VStack(spacing: 16) {
                        // Icon with subtle medical glow
                        ZStack {
                            Circle()
                                .fill(Color.brand.opacity(0.10))
                                .frame(width: 80, height: 80)

                            Image(systemName: "cross.case.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.brand)
                        }
                        .padding(.top, geo.safeAreaInsets.top + 20)

                        VStack(spacing: 6) {
                            Text("Nöbet Devir")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)

                            Text("Klinik Devir-Teslim & Nöbet Yönetimi")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.secondary)
                        }

                        // Feature Pills
                        HStack(spacing: 8) {
                            FeaturePill(icon: "bolt.shield.fill", text: "I-PASS Standardı")
                            FeaturePill(icon: "lock.slash.fill", text: "Sıfır PII")
                            FeaturePill(icon: "wifi.slash", text: "Çevrimdışı")
                        }
                        .padding(.top, 2)
                    }

                    // Onboarding Login Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("NÖBETÇİ HEKİM GİRİŞİ")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.0)
                            .foregroundStyle(.secondary)

                        // Name Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("İsim veya E-posta")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            HStack(spacing: 10) {
                                Image(systemName: "person.text.rectangle.fill")
                                    .foregroundStyle(Color.brand)

                                TextField("Örn. Dr. Ömer", text: $email)
                                    .font(.system(size: 15, weight: .medium))
                                    .autocorrectionDisabled()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(.separator).opacity(0.3), lineWidth: 0.5)
                            )
                        }

                        // Role Selector Grid
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Unvan / Rol")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.primary)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(UserRole.allCases, id: \.self) { r in
                                    let isSelected = role == r
                                    Button {
                                        haptic(.selection)
                                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                            role = r
                                        }
                                    } label: {
                                        HStack(spacing: 7) {
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(isSelected ? Color.brand : .secondary)

                                            Text(r.label)
                                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                                .foregroundStyle(isSelected ? .primary : .secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? Color.brand.opacity(0.10) : Color(.tertiarySystemGroupedBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(isSelected ? Color.brand.opacity(0.5) : Color.clear, lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Enter Shift Button
                        Button {
                            haptic(.medium)
                            let displayName = email.trimmingCharacters(in: .whitespaces).isEmpty ? "Dr. Ömer" : email
                            store.login(email: displayName, role: role)
                        } label: {
                            HStack(spacing: 8) {
                                Text("Nöbete Başla")
                                    .font(.system(size: 16, weight: .bold))

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brand)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.brand.opacity(0.25), radius: 8, y: 3)
                        }
                        .padding(.top, 4)

                        // Join Team with Invite Code
                        Button {
                            haptic()
                            showJoinSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 13))
                                Text("Davet Kodu ile Ekibe Katıl")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(Color.brand)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(20)
                    .card()
                    .padding(.horizontal, 20)

                    // Medical Disclaimer
                    Text("Klinik karar destek aracıdır, tıbbi cihaz değildir. Karar ve sorumluluk hekime aittir.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .sheet(isPresented: $showJoinSheet) {
                JoinTeamSheet()
            }
        }
    }
}

// MARK: - Feature Pill Helper

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
    }
}
