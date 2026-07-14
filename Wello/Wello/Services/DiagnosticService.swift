import Foundation
import MetricKit
import OSLog
import UIKit

/// Un incident retenu par le système (crash, blocage, terminaison forcée), tel que MetricKit nous
/// le livre — **au lancement suivant**, jamais sur le moment.
struct IncidentDiagnostiqué: Codable, Identifiable, Sendable {
    var id = UUID()
    /// Date de livraison par MetricKit (≈ le jour de l'incident ; MetricKit livre par lots).
    let date: Date
    /// « Crash », « Blocage »… — famille de l'incident.
    let genre: String
    /// Cause telle que rapportée (signal, exception, motif de terminaison). Jamais de données perso.
    let cause: String
    /// Version de l'app au moment de l'incident.
    let version: String
}

/// Collecte les diagnostics de crash/blocage **sur l'appareil**, via MetricKit.
///
/// Wello n'envoie rien : pas de SDK, pas de serveur. iOS remet ces rapports à l'app elle-même au
/// lancement suivant ; on les conserve localement pour que l'utilisateur puisse **choisir** de les
/// joindre à un signalement (Profil ▸ Aide). Sans ça, un crash en production ne laisserait aucune
/// trace exploitable de ton côté, sauf à espérer que l'utilisateur ait accepté de partager ses
/// analytics avec les développeurs (Xcode Organizer).
///
/// MetricKit ne transmet que des données système anonymes (signaux, piles d'appel) : aucune donnée
/// de santé, aucune position.
@MainActor
@Observable
final class DiagnosticService: NSObject, MXMetricManagerSubscriber {
    /// Incidents conservés (les plus récents d'abord), plafonnés : c'est un carnet de bord, pas
    /// une base de données.
    private(set) var incidents: [IncidentDiagnostiqué] = []

    private static let clé = "wello.diagnostics.incidents"
    private static let maxIncidents = 10

    override init() {
        super.init()
        incidents = Self.chargés()
    }

    /// À appeler une fois au démarrage. MetricKit livrera les rapports en attente peu après.
    func démarrer() {
        MXMetricManager.shared.add(self)
    }

    func arrêter() {
        MXMetricManager.shared.remove(self)
    }

    /// Version affichable de l'app (« 1.0 (12) »).
    static var version: String {
        let info = Bundle.main.infoDictionary
        let court = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(court) (\(build))"
    }

    // MARK: MXMetricManagerSubscriber

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // MetricKit appelle hors MainActor ; on repasse pour muter l'état observé.
        let nouveaux = payloads.flatMap { Self.extraire($0) }
        Task { @MainActor in
            guard !nouveaux.isEmpty else { return }
            WelloLog.app.notice("MetricKit a livré \(nouveaux.count, privacy: .public) incident(s)")
            incidents = Array((nouveaux + incidents).prefix(Self.maxIncidents))
            Self.enregistrer(incidents)
        }
    }

    /// Traduit un lot MetricKit en incidents lisibles. On ne garde que le motif : les piles
    /// d'appel complètes n'ont d'intérêt que symbolisées, ce que fait déjà l'Organizer Xcode.
    private nonisolated static func extraire(_ payload: MXDiagnosticPayload) -> [IncidentDiagnostiqué] {
        let date = payload.timeStampEnd
        var incidents: [IncidentDiagnostiqué] = []

        for crash in payload.crashDiagnostics ?? [] {
            let méta = crash.metaData
            let signal = crash.signal.map { "signal \($0)" }
            let exception = crash.exceptionType.map { "exception \($0)" }
            let raison = crash.terminationReason ?? [signal, exception].compactMap { $0 }.joined(separator: ", ")
            incidents.append(IncidentDiagnostiqué(
                date: date, genre: "Crash",
                cause: raison.isEmpty ? "cause non rapportée" : raison,
                version: méta.applicationBuildVersion))
        }
        for hang in payload.hangDiagnostics ?? [] {
            incidents.append(IncidentDiagnostiqué(
                date: date, genre: "Blocage",
                cause: "interface figée \(hang.hangDuration.value) \(hang.hangDuration.unit.symbol)",
                version: hang.metaData.applicationBuildVersion))
        }
        return incidents
    }

    // MARK: Persistance (UserDefaults : quelques entrées, pas un flux)

    private static func chargés() -> [IncidentDiagnostiqué] {
        guard let data = UserDefaults.standard.data(forKey: clé),
              let décodés = try? JSONDecoder().decode([IncidentDiagnostiqué].self, from: data)
        else { return [] }
        return décodés
    }

    private static func enregistrer(_ incidents: [IncidentDiagnostiqué]) {
        guard let data = try? JSONEncoder().encode(incidents) else { return }
        UserDefaults.standard.set(data, forKey: clé)
    }

    /// Oublie les incidents conservés (l'utilisateur reste maître de ce qui vit sur son appareil).
    func oublier() {
        incidents = []
        UserDefaults.standard.removeObject(forKey: Self.clé)
    }
}
