/// Instantané météo du jour utilisé pour le bonus d'hydratation.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Température moyenne du jour, en °C.
    public let temperatureC: Double
    /// Humidité relative moyenne du jour, en %.
    public let humidityPct: Double

    public init(temperatureC: Double, humidityPct: Double) {
        self.temperatureC = temperatureC
        self.humidityPct = humidityPct
    }
}
