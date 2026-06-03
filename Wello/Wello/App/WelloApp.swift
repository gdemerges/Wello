import SwiftUI
import SwiftData

@main
struct WelloApp: App {
    /// Conteneur SwiftData pour les 3 modèles.
    let container: ModelContainer
    @State private var store: HydrationStore

    init() {
        let container = try! ModelContainer(for: UserProfile.self, DailyGoal.self, HydrationLog.self)
        self.container = container
        // Services réels injectés dans l'orchestrateur.
        _store = State(initialValue: HydrationStore(
            modelContext: container.mainContext,
            healthKit: HealthKitService(),
            weather: WeatherService(),
            location: LocationService(),
            notifications: NotificationService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                MainView()
                    .tabItem { Label("Aujourd'hui", systemImage: "drop.fill") }
                HistoryView()
                    .tabItem { Label("Historique", systemImage: "calendar") }
                ProfileView()
                    .tabItem { Label("Profil", systemImage: "person.fill") }
            }
            .environment(store)
        }
        .modelContainer(container)
    }
}
