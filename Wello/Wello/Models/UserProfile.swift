import Foundation
import SwiftData
import WelloKit

/// Profil unique de l'utilisateur (app mono-utilisateur).
@Model
final class UserProfile {
    /// Plancher médical fixe (ex. 2500 ml) — suivi de calculs rénaux calciques.
    var medicalFloorML: Int
    var remindersEnabled: Bool
    /// Sexe biologique pour la base EFSA. Stocké en brut (String?) pour la migration légère
    /// SwiftData ; nil = pas encore renseigné (force l'onboarding). Exposé via `sexe`.
    var sexeRaw: String? = nil
    /// Montants des 3 boutons d'ajout rapide (personnalisables). Défauts inline pour
    /// la migration légère SwiftData.
    var quickAdd1: Int = 150
    var quickAdd2: Int = 250
    var quickAdd3: Int = 500
    var updatedAt: Date

    /// Les 3 montants rapides dans l'ordre, pour itération en UI.
    var quickAdds: [Int] { [quickAdd1, quickAdd2, quickAdd3] }

    /// Sexe biologique, ou nil si non renseigné.
    var sexe: BiologicalSex? {
        get { sexeRaw.flatMap(BiologicalSex.init(rawValue:)) }
        set { sexeRaw = newValue?.rawValue }
    }

    init(medicalFloorML: Int = 2500, remindersEnabled: Bool = true,
         quickAdd1: Int = 150, quickAdd2: Int = 250, quickAdd3: Int = 500,
         updatedAt: Date = .now) {
        self.medicalFloorML = medicalFloorML
        self.remindersEnabled = remindersEnabled
        self.quickAdd1 = quickAdd1
        self.quickAdd2 = quickAdd2
        self.quickAdd3 = quickAdd3
        self.updatedAt = updatedAt
    }
}
