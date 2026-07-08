/// Instantané météo du jour utilisé pour le bonus d'hydratation.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Température ressentie maximale du jour, en °C. La « ressentie » (apparent temperature)
    /// intègre déjà humidité, vent et rayonnement — un seul driver cohérent du stress thermique,
    /// donc de la perte sudorale.
    public let apparentTemperatureC: Double

    /// Altitude du lieu (mètres), issue d'Open-Meteo. `nil` si indisponible → aucun bonus altitude.
    /// En altitude, les besoins hydriques augmentent (pertes respiratoires accrues + diurèse).
    public let altitudeM: Double?

    public init(apparentTemperatureC: Double, altitudeM: Double? = nil) {
        self.apparentTemperatureC = apparentTemperatureC
        self.altitudeM = altitudeM
    }
}
