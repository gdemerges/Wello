/// Calcul pur de l'objectif d'hydratation quotidien.
/// Aucune dépendance Apple framework : entièrement testable hors Xcode.
public struct HydrationCalculator: Sendable {

    /// Constantes médicales/algorithmiques nommées (cf. spec).
    public enum Constantes {
        /// Cible de boisson EFSA 2010 (eau totale 2,5 L / 2,0 L, dont ~80 % via les boissons).
        public static let baseHommeML = 2000
        public static let baseFemmeML = 1600
        /// ml d'eau par kcal d'énergie active. Base scientifique : évaporer 1 mL de sueur
        /// dissipe ~0,58 kcal ; à l'effort ~75-80 % de l'énergie devient chaleur, dissipée
        /// majoritairement par la sueur → ~1 mL/kcal (coefficient conservateur).
        public static let mlParKcal = 1.0
        public static let plafondActivité = 1000
        /// Température ressentie (°C) en dessous de laquelle aucun bonus météo (zone de confort).
        public static let seuilConfortRessentiC = 27.0
        /// ml d'eau supplémentaires par °C ressenti au-dessus du seuil de confort.
        public static let mlParDegréRessenti = 50.0
        /// Plafond du bonus météo (≈ +12°C ressentis au-dessus du confort).
        public static let plafondMétéo = 600
        /// Altitude (m) au-dessus de laquelle un bonus s'applique. En dessous : aucun effet.
        /// En altitude, l'hydratation augmente (pertes respiratoires accrues par l'air sec + diurèse).
        public static let seuilAltitudeM = 2000.0
        /// ml d'eau supplémentaires par tranche de 1000 m au-dessus du seuil.
        public static let mlParMilleMètres = 150.0
        /// Plafond du bonus altitude (conservateur).
        public static let plafondAltitude = 500
        /// Poids de référence (kg) de la base EFSA, par sexe : l'ajustement de corpulence mesure
        /// l'écart à cette référence. Valeurs usuelles population adulte.
        public static let poidsRéférenceHommeKg = 70.0
        public static let poidsRéférenceFemmeKg = 60.0
        /// Fraction de l'écart relatif de poids répercutée sur la base. Volontairement modérée
        /// (0,5) : la base EFSA reste le socle, la corpulence ne fait que l'affiner. On n'adopte
        /// PAS le « 35 ml/kg » (qui estime l'eau totale et surestime la cible de boisson).
        public static let facteurCorpulence = 0.5
        /// Plafond (± ml) de l'ajustement de corpulence, pour rester une correction et non un recalcul.
        public static let plafondCorpulence = 400
        /// Plafond de sécurité global : on n'affiche jamais d'objectif supérieur.
        public static let plafondGlobal = 4000
    }

    public init() {}

    public func calculate(_ inputs: CalculatorInputs) -> GoalBreakdown {
        let t = inputs.tuning
        let base = inputs.sex == .homme ? Constantes.baseHommeML : Constantes.baseFemmeML

        // Réglage avancé : la sensibilité multiplie le bonus AVANT son plafond de sécurité.
        let activité = min(Int((inputs.activeEnergyKcal * Constantes.mlParKcal * t.activityMultiplier).rounded()),
                           Constantes.plafondActivité)

        let météo = bonusMétéo(inputs.weather, multiplicateur: t.weatherMultiplier)
        let altitude = bonusAltitude(inputs.weather)

        let étatPhysio = inputs.physiologicalState.bonusML
        // Garde-fou : un besoin rénal négatif (saisie aberrante) ne retire jamais d'eau.
        let rénal = max(0, inputs.renalBonusML)

        // Ajustement de corpulence (Wello+) : écart borné à la base selon le poids. 0 si non fourni.
        let corpulence = ajustementCorpulence(poidsKg: inputs.bodyWeightKg, sexe: inputs.sex, base: base)

        // Ajustement manuel (peut être négatif) ; le total est borné ≥ 0 puis au plafond.
        let physiologique = max(0, base + activité + météo + altitude + étatPhysio + rénal
                                + corpulence + t.manualAdjustmentML)
        // Plafond de sécurité anti-hyperhydratation : unique garde-fou (plus de plancher).
        let total = min(Constantes.plafondGlobal, physiologique)

        return GoalBreakdown(
            baseML: base,
            activityBonusML: activité,
            weatherBonusML: météo,
            altitudeBonusML: altitude,
            lifeStageBonusML: étatPhysio,
            renalBonusML: rénal,
            bodyBonusML: corpulence,
            manualAdjustmentML: t.manualAdjustmentML,
            totalML: total,
            plafondAppliqué: physiologique > Constantes.plafondGlobal
        )
    }

    /// Bonus d'altitude : montée linéaire au-delà du seuil, plafonnée. 0 si altitude absente/en plaine.
    private func bonusAltitude(_ weather: WeatherSnapshot?) -> Int {
        guard let altitude = weather?.altitudeM else { return 0 }
        let excès = altitude - Constantes.seuilAltitudeM
        guard excès > 0 else { return 0 }
        return min(Int((excès / 1000 * Constantes.mlParMilleMètres).rounded()), Constantes.plafondAltitude)
    }

    /// Ajustement de corpulence : fraction bornée de l'écart relatif de poids à la référence du sexe,
    /// appliquée à la base EFSA. Signé (négatif si plus léger que la référence). 0 si poids non fourni.
    private func ajustementCorpulence(poidsKg: Double?, sexe: BiologicalSex, base: Int) -> Int {
        guard let poids = poidsKg, poids > 0 else { return 0 }
        let référence = sexe == .homme ? Constantes.poidsRéférenceHommeKg : Constantes.poidsRéférenceFemmeKg
        let écartRelatif = (poids - référence) / référence
        let brut = Double(base) * Constantes.facteurCorpulence * écartRelatif
        let borné = max(-Double(Constantes.plafondCorpulence), min(Double(Constantes.plafondCorpulence), brut))
        return Int(borné.rounded())
    }

    private func bonusMétéo(_ weather: WeatherSnapshot?, multiplicateur: Double) -> Int {
        guard let w = weather else { return 0 }   // météo absente → bonus 0
        // Montée linéaire à partir du seuil de confort, plafonnée. La température ressentie
        // combine déjà chaleur + humidité + vent (cf. WeatherSnapshot).
        let excès = w.apparentTemperatureC - Constantes.seuilConfortRessentiC
        guard excès > 0 else { return 0 }
        return min(Int((excès * Constantes.mlParDegréRessenti * multiplicateur).rounded()), Constantes.plafondMétéo)
    }
}
