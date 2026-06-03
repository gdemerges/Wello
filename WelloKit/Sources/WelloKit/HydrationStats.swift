/// Total d'un jour : consommé vs objectif. Brique des statistiques d'historique.
public struct DailyTotal: Sendable, Equatable {
    public let consumedML: Int
    public let goalML: Int

    public init(consumedML: Int, goalML: Int) {
        self.consumedML = consumedML
        self.goalML = goalML
    }

    /// Objectif atteint ce jour-là.
    public var reached: Bool { goalML > 0 && consumedML >= goalML }
}

/// Statistiques d'hydratation dérivées d'une suite de jours. Fonctions pures, testables.
public enum HydrationStats {

    /// Série de jours consécutifs ayant atteint l'objectif, en partant du plus récent.
    /// `days` doit être ordonné du plus récent au plus ancien.
    public static func currentStreak(_ days: [DailyTotal]) -> Int {
        var n = 0
        for d in days {
            if d.reached { n += 1 } else { break }
        }
        return n
    }

    /// Moyenne du consommé (ml) sur les `lastN` jours les plus récents.
    /// `days` ordonné du plus récent au plus ancien. 0 si vide.
    public static func averageConsumed(_ days: [DailyTotal], lastN: Int) -> Int {
        let échantillon = Array(days.prefix(max(0, lastN)))
        guard !échantillon.isEmpty else { return 0 }
        return échantillon.reduce(0) { $0 + $1.consumedML } / échantillon.count
    }
}
