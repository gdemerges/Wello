import Foundation
import Observation
import UIKit
import WelloKit

/// Thème de couleur sélectionné (Wello+). Persisté en `UserDefaults` et appliqué à `WelloTheme`
/// (palette) + icône alternative de l'app. Injecté via `.environment` (comme `DrinkCatalog`).
/// La sélection d'un thème premium est gatée à l'UI ; `enforceEntitlement` couvre la perte de droit.
@MainActor
@Observable
final class ThemeStore {
    private let defaults: UserDefaults
    private(set) var selected: AppTheme

    private static let key = "wello.theme"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let theme = defaults.string(forKey: Self.key).flatMap(AppTheme.init(rawValue:)) ?? .glacier
        self.selected = theme
        WelloTheme.current = theme
        appliquerIcône(theme.alternateIconName)
    }

    /// Applique un thème : palette + persistance + icône. Le gating premium est fait par l'appelant.
    func select(_ theme: AppTheme) {
        guard theme != selected else { return }
        selected = theme
        WelloTheme.current = theme
        defaults.set(theme.rawValue, forKey: Self.key)
        appliquerIcône(theme.alternateIconName)
    }

    /// Repasse en thème par défaut si un thème premium est actif sans droit (remboursement).
    /// À appeler une fois le statut d'entitlement résolu.
    func enforceEntitlement(unlocked: Bool) {
        if !unlocked && !selected.estGratuit {
            select(.glacier)
        }
    }

    /// Bascule l'icône de l'app. `nil` = icône primaire. Silencieux si non supporté ou assets absents.
    private func appliquerIcône(_ name: String?) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != name else { return }
        UIApplication.shared.setAlternateIconName(name) { _ in }   // échec ignoré (best-effort)
    }
}
