import SwiftUI

import SwiftData

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var ctx

    var body: some View {
        ZStack {
            if store.isLoggedIn {
                if store.isBiometricsEnabled && !store.isUnlocked {
                    BiometricLockView()
                } else {
                    MainTabView()
                }
            } else {
                LoginView()
            }

            // Privacy shield for App Switcher & backgrounding
            if scenePhase != .active && store.isLoggedIn {
                PrivacyShieldView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: scenePhase)
        .animation(.easeInOut(duration: 0.2), value: store.isUnlocked)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.performRetentionCleanup(ctx: ctx)
            } else if newPhase == .background {
                if store.isBiometricsEnabled {
                    store.isUnlocked = false
                }
            }
        }
        .onOpenURL { url in
            store.handleDeepLink(url: url, ctx: ctx)
        }
        .onAppear {
            store.deduplicateExistingData(ctx: ctx)
            store.performRetentionCleanup(ctx: ctx)
            if store.isBiometricsEnabled {
                store.authenticateBiometrics()
            }
        }
    }
}

// MARK: - Privacy Shield View

struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.brand)

                Text("Nöbet Devir")
                    .font(.system(size: 24, weight: .bold))

                Text("Gizlilik Koruması Aktif")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("Hasta verileri uygulama değiştiricide gizlendi.")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .padding(24)
        }
    }
}

// MARK: - Biometric Lock View

struct BiometricLockView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 72))
                .foregroundStyle(Color.brand)

            VStack(spacing: 8) {
                Text("Nöbet Devir Kilitli")
                    .font(.system(size: 24, weight: .bold))

                Text("Klinik hasta kayıtlarına erişmek için biyometrik doğrulama gereklidir.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                haptic()
                store.authenticateBiometrics()
            } label: {
                Label("Kilidi Aç", systemImage: "touchid")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brand)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: Color.brand.opacity(0.25), radius: 8, y: 3)
            }
            .padding(.horizontal, 32)
            .padding(.top, 12)

            Spacer()
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}


// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var s = store
        TabView(selection: $s.currentTab) {
            PanoView()
                .tabItem {
                    Label("Devir", systemImage: "list.clipboard")
                }
                .tag(AppTab.pano)

            ClinicalScoresView()
                .tabItem {
                    Label("Skorlar", systemImage: "stethoscope")
                }
                .tag(AppTab.skorlar)

            TeamView()
                .tabItem {
                    Label("Ekip", systemImage: "person.2")
                }
                .tag(AppTab.ekip)

            ProfileView()
                .tabItem {
                    Label("Profil", systemImage: "person.circle")
                }
                .tag(AppTab.profil)
        }
        .tint(Color.brand)
        .task {
            await NotificationManager.shared.requestPermission()
        }
    }
}
