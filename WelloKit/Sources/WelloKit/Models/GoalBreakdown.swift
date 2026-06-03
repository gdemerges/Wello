/// Résultat détaillé du calcul, pour affichage du breakdown dans l'UI.
public struct GoalBreakdown: Sendable, Equatable {
    public let baseML: Int
    public let activityBonusML: Int
    public let weatherBonusML: Int
    /// Plancher médical, repris des entrées : volontaire, pour que le breakdown soit
    /// autonome (affichage UI + persistance du DailyGoal sans relire les entrées).
    public let medicalFloorML: Int
    public let totalML: Int
    /// Vrai si le plancher médical a relevé l'objectif au-dessus du besoin physiologique.
    public let plancherContraignant: Bool
    /// Vrai si l'objectif a été bridé au plafond de sécurité (anti-hyperhydratation).
    public let plafondAppliqué: Bool

    /// Besoin physiologique = somme des termes additionnés (base + activité + météo).
    /// Distinct du plancher médical, qui est un seuil (max) et non un terme.
    public var physiologicalML: Int { baseML + activityBonusML + weatherBonusML }

    public init(baseML: Int, activityBonusML: Int, weatherBonusML: Int, medicalFloorML: Int,
                totalML: Int, plancherContraignant: Bool, plafondAppliqué: Bool) {
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.medicalFloorML = medicalFloorML
        self.totalML = totalML
        self.plancherContraignant = plancherContraignant
        self.plafondAppliqué = plafondAppliqué
    }
}
