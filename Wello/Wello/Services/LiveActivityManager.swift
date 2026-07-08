import Foundation
import ActivityKit

/// Gère la Live Activity d'hydratation du jour : démarrage paresseux à la première prise,
/// mises à jour à chaque changement, fin quand il n'y a plus d'objectif (nouveau jour non calculé).
///
/// Entièrement inerte si l'utilisateur a désactivé les Live Activities (réglages) ou si le
/// système ne les supporte pas : aucune erreur remontée, l'app reste utilisable normalement.
@MainActor
final class LiveActivityManager {
    private var activité: Activity<HydrationActivityAttributes>?

    /// Démarre la Live Activity si aucune n'est en cours, sinon met à jour son contenu.
    /// No-op tant que l'objectif n'est pas calculé (`objectifML == 0`) : on termine alors une
    /// éventuelle activité résiduelle.
    func mettreÀJour(consomméML: Int, objectifML: Int) {
        guard objectifML > 0 else { terminer(); return }
        let état = HydrationActivityAttributes.ContentState(consomméML: consomméML, objectifML: objectifML)

        if let activité {
            Task { await activité.update(ActivityContent(state: état, staleDate: nil)) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            activité = try? Activity.request(
                attributes: HydrationActivityAttributes(),
                content: ActivityContent(state: état, staleDate: nil),
                pushType: nil)
        }
    }

    /// Termine immédiatement la Live Activity en cours (fin de journée / objectif indisponible).
    func terminer() {
        guard let activité else { return }
        let dernierÉtat = activité.content.state
        Task {
            await activité.end(ActivityContent(state: dernierÉtat, staleDate: nil),
                               dismissalPolicy: .immediate)
        }
        self.activité = nil
    }
}
