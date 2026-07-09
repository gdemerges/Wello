import Foundation

/// Un enseignement tiré de la répartition horaire des prises. **Sémantique** (genre + tranche) →
/// l'app rend le texte localisé, comme `MessageRappel`.
public struct Insight: Sendable, Equatable, Identifiable {
    public enum Genre: Sendable, Equatable {
        /// Boit surtout à telle tranche (`période` renseignée).
        case pic
        /// Telle tranche de journée décroche (`période` renseignée).
        case creux
        /// Boit une large part en soirée/nuit (`période` nil).
        case tardif
        /// Répartition équilibrée sur la journée (`période` nil).
        case équilibré
    }
    public let genre: Genre
    public let période: DayPeriod?

    public var id: String { "\(genre)-\(période?.rawValue ?? "-")" }

    public init(genre: Genre, période: DayPeriod?) {
        self.genre = genre
        self.période = période
    }
}

/// Dérive 0 à 2 enseignements de la répartition horaire des prises. Pur → testable.
public enum GénérateurInsights {
    /// Part soirée+nuit au-delà de laquelle on signale un profil « tardif » (impact sommeil).
    static let seuilTardif = 0.40
    /// Au-delà de cette part pour la tranche dominante, on parle de « pic ».
    static let seuilPic = 0.35
    /// Sous cette part du total pour une tranche diurne, on la juge « en creux ».
    static let seuilCreux = 0.12

    private static let diurnes: [DayPeriod] = [.matin, .midi, .apresMidi, .soiree]

    /// `répartition` : ml par tranche (les 5, ordre canonique) — sortie de `hydrationByPeriod`.
    /// `minTotalML` : recul minimal avant de conclure quoi que ce soit (évite la fausse précision).
    /// Renvoie au plus 2 enseignements, priorisés (tardif > pic > creux > équilibré).
    public static func analyser(_ répartition: [(period: DayPeriod, ml: Int)],
                                minTotalML: Int = 3000) -> [Insight] {
        let total = répartition.reduce(0) { $0 + $1.ml }
        guard total >= minTotalML else { return [] }

        func part(_ p: DayPeriod) -> Double {
            Double(répartition.first { $0.period == p }?.ml ?? 0) / Double(total)
        }

        var out: [Insight] = []

        // 1. Profil tardif (priorité : impact sur le sommeil).
        let tardif = part(.soiree) + part(.nuit)
        if tardif >= seuilTardif {
            out.append(Insight(genre: .tardif, période: nil))
        }

        // 2. Pic diurne dominant — hors soirée si le profil tardif est déjà signalé (redondance).
        if let dominante = diurnes.max(by: { part($0) < part($1) }),
           part(dominante) >= seuilPic,
           !(dominante == .soiree && tardif >= seuilTardif) {
            out.append(Insight(genre: .pic, période: dominante))
        }

        // 3. Creux diurne (tranche la plus faible, nettement sous le reste).
        if let creux = diurnes.min(by: { part($0) < part($1) }), part(creux) < seuilCreux {
            out.append(Insight(genre: .creux, période: creux))
        }

        // 4. Sinon, répartition équilibrée.
        if out.isEmpty {
            out.append(Insight(genre: .équilibré, période: nil))
        }
        return Array(out.prefix(2))
    }
}
