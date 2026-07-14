import Foundation

/// Règle de validité du relevé météo mis en cache.
///
/// Deux appelants aux exigences opposées :
/// - **au premier plan**, on veut une météo récente (fenêtre courte) — quitte à refaire un fix GPS
///   et un appel réseau, l'utilisateur est là et l'app a le droit de localiser ;
/// - **réveillé en arrière-plan** par HealthKit (séance terminée), on n'a ni le droit ni le temps
///   d'un fix GPS. Là, refuser un relevé « vieux de 3 h » serait un piège : le recalcul repartirait
///   sans bonus météo et **baisserait** l'objectif du jour d'un cran que l'utilisateur n'a pas
///   demandé. On accepte donc n'importe quel relevé **du jour même** (`fenêtre: nil`).
///
/// Dans tous les cas, un relevé d'un autre jour est refusé : la météo du jour est le seul intrant
/// pertinent, et la garder franchirait minuit avec une valeur périmée.
///
/// - Parameter fenêtre: âge maximal accepté, en secondes. `nil` = pas de limite d'âge (mais
///   toujours le jour même).
public func météoUtilisable(capturéeÀ: Date,
                            maintenant: Date,
                            fenêtre: TimeInterval?,
                            calendar: Calendar = .current) -> Bool {
    guard calendar.isDate(capturéeÀ, inSameDayAs: maintenant) else { return false }
    // Un relevé « du futur » (horloge reculée, changement de fuseau) : on le refuse plutôt que de
    // le traiter comme infiniment frais.
    let âge = maintenant.timeIntervalSince(capturéeÀ)
    guard âge >= 0 else { return false }
    guard let fenêtre else { return true }
    return âge < fenêtre
}
