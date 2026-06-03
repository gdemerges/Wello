import Foundation
import WelloKit

/// Récupère la météo du jour via Open-Meteo (gratuit, sans clé). Best-effort : nil sur échec.
struct WeatherService: WeatherServicing {

    func météoDuJour(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            // Température ressentie max du jour : intègre humidité + vent + rayonnement.
            .init(name: "daily", value: "apparent_temperature_max"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, réponse) = try await URLSession.shared.data(from: url)
            guard (réponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let dto = try JSONDecoder().decode(OpenMeteoDTO.self, from: data)
            guard let ressentieMax = dto.daily.apparent_temperature_max.first else { return nil }
            return WeatherSnapshot(apparentTemperatureC: ressentieMax)
        } catch {
            return nil   // réseau/API down → météo absente, le calcul tourne quand même
        }
    }
}

/// DTO interne de décodage Open-Meteo.
private struct OpenMeteoDTO: Decodable {
    struct Daily: Decodable { let apparent_temperature_max: [Double] }
    let daily: Daily
}
