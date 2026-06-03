/// Instantané météo du jour utilisé pour le bonus d'hydratation.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Température ressentie maximale du jour, en °C. La « ressentie » (apparent temperature)
    /// intègre déjà humidité, vent et rayonnement — un seul driver cohérent du stress thermique,
    /// donc de la perte sudorale.
    public let apparentTemperatureC: Double

    public init(apparentTemperatureC: Double) {
        self.apparentTemperatureC = apparentTemperatureC
    }
}
