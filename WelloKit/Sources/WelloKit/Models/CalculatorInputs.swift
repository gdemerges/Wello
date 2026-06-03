/// Entrées du calcul d'objectif d'hydratation. `weather` est optionnel :
/// si la météo est indisponible (réseau/API down), le bonus météo vaut 0.
public struct CalculatorInputs: Sendable, Equatable {
    public let weightKg: Double
    /// Énergie active brûlée à l'effort aujourd'hui (kcal), issue de HealthKit.
    /// Proxy physiologique de la perte sudorale (intensité, pas seulement durée).
    public let activeEnergyKcal: Double
    public let weather: WeatherSnapshot?
    public let medicalFloorML: Int

    public init(weightKg: Double, activeEnergyKcal: Double, weather: WeatherSnapshot?, medicalFloorML: Int) {
        self.weightKg = weightKg
        self.activeEnergyKcal = activeEnergyKcal
        self.weather = weather
        self.medicalFloorML = medicalFloorML
    }
}
