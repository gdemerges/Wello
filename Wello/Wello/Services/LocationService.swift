import Foundation
import CoreLocation
import OSLog

/// Fournit les coordonnées actuelles en one-shot pour alimenter la météo. Best-effort.
///
/// `@unchecked Sendable` : tout l'état mutable (continuations) n'est accédé que depuis le
/// contexte d'appel de l'appelant (MainActor dans cette app) et les callbacks du délégué, qui
/// s'exécutent sérialisés sur la même file par `CLLocationManager`.
final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    /// Continuation en attente de la réponse à `requestWhenInUseAuthorization` (statut encore
    /// `.notDetermined` à l'appel). Une seule à la fois : la 1ʳᵉ demande d'autorisation du
    /// process couvre tous les appelants concurrents.
    private var continuationAutorisation: CheckedContinuation<Bool, Never>?
    /// Continuations en attente d'un fix GPS. Une file plutôt qu'un unique optionnel : si deux
    /// appels se chevauchent (ex. refresh manuel pendant un refresh en cours), le 2ᵉ n'écrase
    /// plus le 1ᵉʳ (qui restait alors bloqué à vie, une fuite de continuation) — les deux
    /// reçoivent le même résultat, une seule requête `requestLocation()` étant émise.
    private var continuationsLocalisation: [CheckedContinuation<(latitude: Double, longitude: Double)?, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func coordonnéesActuelles() async -> (latitude: Double, longitude: Double)? {
        let statut = manager.authorizationStatus
        guard statut != .denied, statut != .restricted else {
            // Cause n° 1 d'une « météo qui ne marche pas » : l'autorisation, pas le réseau.
            WelloLog.météo.notice("localisation refusée (statut \(statut.rawValue, privacy: .public)) → pas de météo")
            return nil
        }
        if statut == .notDetermined {
            guard await attendreAutorisation() else { return nil }
        }
        return await demanderLocalisation()
    }

    /// Attend la résolution de la boîte de dialogue système avant de tenter un fix GPS : lancer
    /// `requestLocation()` immédiatement après `requestWhenInUseAuthorization()` (sans attendre
    /// la réponse) échouait systématiquement en `.notDetermined` → météo absente au tout premier
    /// lancement, avant même que l'utilisateur ait répondu.
    private func attendreAutorisation() async -> Bool {
        await withCheckedContinuation { cont in
            continuationAutorisation = cont
            manager.requestWhenInUseAuthorization()
        }
    }

    private func demanderLocalisation() async -> (latitude: Double, longitude: Double)? {
        await withCheckedContinuation { cont in
            continuationsLocalisation.append(cont)
            if continuationsLocalisation.count == 1 { manager.requestLocation() }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let cont = continuationAutorisation else { return }
        continuationAutorisation = nil
        let statut = manager.authorizationStatus
        cont.resume(returning: statut == .authorizedWhenInUse || statut == .authorizedAlways)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        let result = coord.map { (latitude: $0.latitude, longitude: $0.longitude) }
        let attente = continuationsLocalisation
        continuationsLocalisation = []
        for cont in attente { cont.resume(returning: result) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        WelloLog.météo.error("fix GPS échoué : \(error.localizedDescription, privacy: .public) → pas de météo")
        let attente = continuationsLocalisation
        continuationsLocalisation = []
        for cont in attente { cont.resume(returning: nil) }
    }
}
