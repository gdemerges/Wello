import Foundation
import WelloKit

/// Récupère la météo du jour via Open-Meteo (gratuit, sans clé). Best-effort : nil sur échec.
struct WeatherService: WeatherServicing {

    func météoDuJour(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "daily", value: "temperature_2m_max"),
            .init(name: "hourly", value: "relative_humidity_2m"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, réponse) = try await URLSession.shared.data(from: url)
            guard (réponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let dto = try JSONDecoder().decode(OpenMeteoDTO.self, from: data)
            guard let tempMax = dto.daily.temperature_2m_max.first else { return nil }
            let humidités = dto.hourly.relative_humidity_2m
            let humiditéMoy = humidités.isEmpty ? 0 : humidités.reduce(0, +) / Double(humidités.count)
            return WeatherSnapshot(temperatureC: tempMax, humidityPct: humiditéMoy)
        } catch {
            return nil   // réseau/API down → météo absente, le calcul tourne quand même
        }
    }
}

/// DTO interne de décodage Open-Meteo.
private struct OpenMeteoDTO: Decodable {
    struct Daily: Decodable { let temperature_2m_max: [Double] }
    struct Hourly: Decodable { let relative_humidity_2m: [Double] }
    let daily: Daily
    let hourly: Hourly
}
