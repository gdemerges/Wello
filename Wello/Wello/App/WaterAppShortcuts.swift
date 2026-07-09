import AppIntents

/// Expose l'ajout d'eau au système : **Siri** (phrases), **Spotlight** (recherche), et le
/// **Bouton Action** (iPhone 15 Pro+) qui peut être configuré sur ce raccourci en une pression.
/// Réutilise `AddWaterIntent` préréglé à 250 ml (le geste rapide par défaut) → aucune saisie,
/// aucune ouverture d'app. Provider dans la cible **app** (Apple les découvre depuis l'app).
struct WaterAppShortcuts: AppShortcutsProvider {
    /// Teinte de la vignette du raccourci dans l'app Raccourcis.
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddWaterIntent(amountML: 250),
            phrases: [
                "Ajoute un verre d'eau à \(.applicationName)",
                "J'ai bu de l'eau dans \(.applicationName)",
                "Note une prise d'eau avec \(.applicationName)",
                "Ajoute de l'eau à \(.applicationName)"
            ],
            shortTitle: "Ajouter 250 ml",
            systemImageName: "drop.fill"
        )
    }
}
