import SwiftUI

/// Racine de l'app : les 3 onglets, avec l'onboarding en plein écran au 1er lancement.
struct RootView: View {
    @Environment(HydrationStore.self) private var store
    @AppStorage("wello.hasOnboarded") private var hasOnboarded = false

    var body: some View {
        TabView {
            MainView()
                .tabItem { Label("Aujourd'hui", systemImage: "drop.fill") }
            HistoryView()
                .tabItem { Label("Historique", systemImage: "calendar") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(WelloTheme.accent)
        .fullScreenCover(isPresented: Binding(get: { !hasOnboarded },
                                              set: { hasOnboarded = !$0 })) {
            OnboardingView {
                hasOnboarded = true
                Task { await store.refreshToday() }   // déclenche les demandes d'autorisation
            }
        }
    }
}
