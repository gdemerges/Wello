import Foundation
import SwiftData

/// Profil unique de l'utilisateur (app mono-utilisateur).
@Model
final class UserProfile {
    var weightKg: Double
    /// Plancher médical fixe (ex. 2500 ml) — suivi de calculs rénaux calciques.
    var medicalFloorML: Int
    var remindersEnabled: Bool
    var updatedAt: Date

    init(weightKg: Double = 75, medicalFloorML: Int = 2500,
         remindersEnabled: Bool = true, updatedAt: Date = .now) {
        self.weightKg = weightKg
        self.medicalFloorML = medicalFloorML
        self.remindersEnabled = remindersEnabled
        self.updatedAt = updatedAt
    }
}
