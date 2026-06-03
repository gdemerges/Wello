/// Calcul pur de l'objectif d'hydratation quotidien.
/// Aucune dépendance Apple framework : entièrement testable hors Xcode.
public struct HydrationCalculator: Sendable {

    /// Constantes médicales/algorithmiques nommées (cf. spec).
    public enum Constantes {
        public static let mlParKg = 35.0
        /// ml d'eau par kcal d'énergie active. Base scientifique : évaporer 1 mL de sueur
        /// dissipe ~0,58 kcal ; à l'effort ~75-80 % de l'énergie devient chaleur, dissipée
        /// majoritairement par la sueur → ~1 mL/kcal (coefficient conservateur).
        public static let mlParKcal = 1.0
        public static let plafondActivité = 1000
        public static let seuilTempC = 28.0
        public static let bonusTemp = 300
        public static let seuilHumiditéPct = 70.0
        public static let bonusHumidité = 200
        /// Plafond de sécurité global : on n'affiche jamais d'objectif supérieur.
        public static let plafondGlobal = 4000
    }

    public init() {}

    public func calculate(_ inputs: CalculatorInputs) -> GoalBreakdown {
        let base = Int((inputs.weightKg * Constantes.mlParKg).rounded())

        let activité = min(Int((inputs.activeEnergyKcal * Constantes.mlParKcal).rounded()), Constantes.plafondActivité)

        let météo = bonusMétéo(inputs.weather)

        let physiologique = base + activité + météo
        // Le plancher médical ne doit jamais être sous-estimé.
        let avantPlafond = max(inputs.medicalFloorML, physiologique)
        // Plafond de sécurité anti-hyperhydratation.
        let total = min(Constantes.plafondGlobal, avantPlafond)

        return GoalBreakdown(
            baseML: base,
            activityBonusML: activité,
            weatherBonusML: météo,
            medicalFloorML: inputs.medicalFloorML,
            totalML: total,
            plancherContraignant: inputs.medicalFloorML > physiologique,
            plafondAppliqué: avantPlafond > Constantes.plafondGlobal
        )
    }

    private func bonusMétéo(_ weather: WeatherSnapshot?) -> Int {
        guard let w = weather else { return 0 }   // météo absente → bonus 0
        var bonus = 0
        if w.temperatureC > Constantes.seuilTempC { bonus += Constantes.bonusTemp }
        if w.humidityPct > Constantes.seuilHumiditéPct { bonus += Constantes.bonusHumidité }
        return bonus
    }
}
