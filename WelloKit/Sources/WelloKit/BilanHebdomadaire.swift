import Foundation

/// Tendance d'une semaine par rapport à la précédente.
public enum TendanceHebdo: Sendable, Equatable { case hausse, stable, baisse }

/// Bilan d'une semaine glissante d'hydratation. Données pures → l'app rend le texte localisé.
public struct BilanHebdo: Sendable, Equatable {
    /// Jours de la semaine ayant atteint l'objectif.
    public let joursAtteints: Int
    /// Jours de la semaine ayant un objectif (≤ 7).
    public let joursComptés: Int
    /// Moyenne du consommé (ml) sur la semaine.
    public let moyenneML: Int
    /// Écart de moyenne vs semaine précédente (ml). 0 si pas de semaine précédente.
    public let deltaML: Int
    /// Vrai seulement si la semaine précédente a des données (sinon pas de comparaison).
    public let aComparaison: Bool
    public let tendance: TendanceHebdo

    public init(joursAtteints: Int, joursComptés: Int, moyenneML: Int,
                deltaML: Int, aComparaison: Bool, tendance: TendanceHebdo) {
        self.joursAtteints = joursAtteints
        self.joursComptés = joursComptés
        self.moyenneML = moyenneML
        self.deltaML = deltaML
        self.aComparaison = aComparaison
        self.tendance = tendance
    }
}

/// Calcule le bilan de la semaine courante (7 jours glissants) et le compare à la précédente.
/// Pur → testable via `swift test`. Sans 2ᵉ semaine (utilisateur récent / gratuit borné à 7 j),
/// le bilan reste valable mais sans comparaison.
public enum BilanHebdomadaire {
    /// Seuil (ml) en deçà duquel l'écart hebdomadaire est jugé « stable ».
    static let seuilStableML = 50

    /// `joursRécents` : totaux jour du plus récent au plus ancien (jusqu'à 14 utilisés).
    /// `nil` si la semaine courante n'a aucun jour.
    public static func calculer(joursRécents: [DailyTotal]) -> BilanHebdo? {
        let semaine = Array(joursRécents.prefix(7))
        guard !semaine.isEmpty else { return nil }
        let précédente = Array(joursRécents.dropFirst(7).prefix(7))

        let moyenne = HydrationStats.averageConsumed(semaine, lastN: 7)
        let moyennePréc = HydrationStats.averageConsumed(précédente, lastN: 7)
        let aComparaison = !précédente.isEmpty
        let delta = aComparaison ? moyenne - moyennePréc : 0
        let tendance: TendanceHebdo = (!aComparaison || abs(delta) < seuilStableML)
            ? .stable
            : (delta > 0 ? .hausse : .baisse)

        return BilanHebdo(joursAtteints: semaine.filter(\.reached).count,
                          joursComptés: semaine.count,
                          moyenneML: moyenne,
                          deltaML: delta,
                          aComparaison: aComparaison,
                          tendance: tendance)
    }
}
