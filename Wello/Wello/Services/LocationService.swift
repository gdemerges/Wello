import Foundation
import CoreLocation

/// Fournit les coordonnées actuelles en one-shot pour alimenter la météo. Best-effort.
///
/// `@unchecked Sendable` : l'accès à `continuation` est sérialisé par le cycle
/// requête → callback du délégué `CLLocationManager`.
final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<(latitude: Double, longitude: Double)?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func coordonnéesActuelles() async -> (latitude: Double, longitude: Double)? {
        let statut = manager.authorizationStatus
        guard statut != .denied, statut != .restricted else { return nil }
        if statut == .notDetermined { manager.requestWhenInUseAuthorization() }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        let result = coord.map { (latitude: $0.latitude, longitude: $0.longitude) }
        continuation?.resume(returning: result)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
