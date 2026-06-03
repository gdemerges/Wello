import Foundation

/// Entrées du calcul d'objectif d'hydratation. `weather` est optionnel :
/// si la météo est indisponible (réseau/API down), le bonus météo vaut 0.
public struct CalculatorInputs: Sendable, Equatable {
    public let weightKg: Double
    public let effortMinutes: Int
    public let weather: WeatherSnapshot?
    public let medicalFloorML: Int

    public init(weightKg: Double, effortMinutes: Int, weather: WeatherSnapshot?, medicalFloorML: Int) {
        self.weightKg = weightKg
        self.effortMinutes = effortMinutes
        self.weather = weather
        self.medicalFloorML = medicalFloorML
    }
}
