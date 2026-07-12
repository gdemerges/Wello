import Testing
import Foundation
@testable import WelloKit

@Suite("WatchSync — codecs dictionnaire")
struct WatchSyncTests {

    @Test("PriseWatch : round-trip dictionnaire plist-safe")
    func priseRoundTrip() {
        let maintenant = Date(timeIntervalSince1970: 1_700_000_000)
        let p = PriseWatch(id: UUID(), amountML: 250, loggedAt: maintenant)
        let dict = p.dictionnaire()
        // Types plist-safe attendus (transportables par WCSession).
        #expect(dict["id"] is String)
        #expect(dict["amountML"] is Int)
        #expect(dict["loggedAt"] is Double)
        let décodé = PriseWatch(dictionnaire: dict, maintenant: maintenant)
        #expect(décodé == p)
    }

    @Test("PriseWatch : dictionnaire invalide → nil")
    func priseInvalide() {
        #expect(PriseWatch(dictionnaire: [:]) == nil)
        #expect(PriseWatch(dictionnaire: ["id": "pas-un-uuid", "amountML": 1, "loggedAt": 0.0]) == nil)
    }

    @Test("PriseWatch : volume hors bornes → nil (garde-fou du canal Watch)")
    func priseVolumeAbsurde() {
        let maintenant = Date(timeIntervalSince1970: 1_700_000_000)
        func dict(_ ml: Int) -> [String: Any] {
            ["id": UUID().uuidString, "amountML": ml, "loggedAt": maintenant.timeIntervalSince1970]
        }
        #expect(PriseWatch(dictionnaire: dict(0), maintenant: maintenant) == nil)
        #expect(PriseWatch(dictionnaire: dict(-250), maintenant: maintenant) == nil)
        #expect(PriseWatch(dictionnaire: dict(3001), maintenant: maintenant) == nil)
        #expect(PriseWatch(dictionnaire: dict(Int.max), maintenant: maintenant) == nil)
        // Bornes incluses : 1 et 3000 passent.
        #expect(PriseWatch(dictionnaire: dict(1), maintenant: maintenant) != nil)
        #expect(PriseWatch(dictionnaire: dict(3000), maintenant: maintenant) != nil)
    }

    @Test("PriseWatch : date absurde → nil, livraison tardive légitime acceptée")
    func priseDateAbsurde() {
        let maintenant = Date(timeIntervalSince1970: 1_700_000_000)
        func dict(décalage: TimeInterval) -> [String: Any] {
            ["id": UUID().uuidString, "amountML": 250,
             "loggedAt": maintenant.addingTimeInterval(décalage).timeIntervalSince1970]
        }
        // Futur : 1 h de dérive d'horloge tolérée, pas plus.
        #expect(PriseWatch(dictionnaire: dict(décalage: 3_599), maintenant: maintenant) != nil)
        #expect(PriseWatch(dictionnaire: dict(décalage: 2 * 3_600), maintenant: maintenant) == nil)
        // Passé : la file transferUserInfo peut livrer avec des jours de retard (29 j OK), pas 31 j.
        #expect(PriseWatch(dictionnaire: dict(décalage: -29 * 86_400), maintenant: maintenant) != nil)
        #expect(PriseWatch(dictionnaire: dict(décalage: -31 * 86_400), maintenant: maintenant) == nil)
    }

    @Test("WatchSyncSnapshot : round-trip complet")
    func snapshotRoundTrip() {
        let s = WatchSyncSnapshot(
            objectifML: 2300, consomméML: 1200, quickAdds: [150, 250, 500], configuré: true,
            sexeRaw: "homme", etatPhysioRaw: nil, renalBonusML: 0,
            activitySensitivity: 1.0, weatherSensitivity: 1.0, manualAdjustmentML: 0,
            acquittés: [UUID(), UUID()], générémLe: Date(timeIntervalSince1970: 1_700_000_000))
        let décodé = WatchSyncSnapshot(dictionnaire: s.dictionnaire())
        #expect(décodé == s)
    }

    @Test("WatchSyncSnapshot : champs optionnels nil préservés")
    func snapshotOptionnels() {
        let s = WatchSyncSnapshot(
            objectifML: 0, consomméML: 0, quickAdds: [150, 250, 500], configuré: false,
            sexeRaw: nil, etatPhysioRaw: nil, renalBonusML: 0,
            activitySensitivity: 1.0, weatherSensitivity: 1.0, manualAdjustmentML: 0,
            acquittés: [], générémLe: Date(timeIntervalSince1970: 0))
        let décodé = WatchSyncSnapshot(dictionnaire: s.dictionnaire())
        #expect(décodé == s)
        #expect(décodé?.sexeRaw == nil)
        #expect(décodé?.acquittés.isEmpty == true)
    }

    @Test("WatchSyncSnapshot : dictionnaire incomplet → nil")
    func snapshotInvalide() {
        #expect(WatchSyncSnapshot(dictionnaire: ["objectifML": 2000]) == nil)
    }
}
