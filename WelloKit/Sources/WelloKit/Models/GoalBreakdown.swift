/// Résultat détaillé du calcul, pour affichage du breakdown dans l'UI.
/// Modèle 100 % additif : le total est la somme des termes, bridée au plafond de sécurité.
public struct GoalBreakdown: Sendable, Equatable {
    public let baseML: Int
    public let activityBonusML: Int
    public let weatherBonusML: Int
    /// Terme additif lié à l'altitude (au-delà d'un seuil). 0 en plaine ou si l'altitude est indisponible.
    public let altitudeBonusML: Int
    /// Terme additif lié à l'état physiologique (grossesse +300 / allaitement +700 / aucun 0).
    public let lifeStageBonusML: Int
    /// Terme additif lié au besoin rénal (lithiase). 0 si désactivé. Toujours ≥ 0 :
    /// `HydrationCalculator.calculate` applique `max(0, …)` avant de construire le breakdown.
    public let renalBonusML: Int
    /// Ajustement de corpulence (Wello+) : écart borné à la base EFSA selon le poids. Peut être
    /// négatif (corpulence < référence). 0 si non personnalisé.
    public let bodyBonusML: Int
    /// Terme additif du réglage avancé (ajustement manuel, Wello+). Peut être négatif. 0 par défaut.
    public let manualAdjustmentML: Int
    public let totalML: Int
    /// Vrai si l'objectif a été bridé au plafond de sécurité (anti-hyperhydratation).
    public let plafondAppliqué: Bool

    /// Besoin physiologique = somme de tous les termes additifs (= total avant plafond, borné ≥ 0).
    public var physiologicalML: Int {
        max(0, baseML + activityBonusML + weatherBonusML + altitudeBonusML + lifeStageBonusML
            + renalBonusML + bodyBonusML + manualAdjustmentML)
    }

    public init(baseML: Int, activityBonusML: Int, weatherBonusML: Int, altitudeBonusML: Int = 0,
                lifeStageBonusML: Int, renalBonusML: Int, bodyBonusML: Int = 0,
                manualAdjustmentML: Int = 0, totalML: Int, plafondAppliqué: Bool) {
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.altitudeBonusML = altitudeBonusML
        self.lifeStageBonusML = lifeStageBonusML
        self.renalBonusML = renalBonusML
        self.bodyBonusML = bodyBonusML
        self.manualAdjustmentML = manualAdjustmentML
        self.totalML = totalML
        self.plafondAppliqué = plafondAppliqué
    }
}
