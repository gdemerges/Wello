import ActivityKit

/// Attributs de la Live Activity de progression d'hydratation du jour (écran verrouillé +
/// Dynamic Island). Fichier **partagé** : l'app (cible Wello) démarre/actualise l'activité,
/// l'extension widget (cible WelloWidget) en rend l'UI. Doit donc être membre des DEUX cibles.
struct HydrationActivityAttributes: ActivityAttributes {
    /// État dynamique poussé à chaque prise : consommé et objectif du jour.
    public struct ContentState: Codable, Hashable {
        public var consomméML: Int
        public var objectifML: Int

        public init(consomméML: Int, objectifML: Int) {
            self.consomméML = consomméML
            self.objectifML = objectifML
        }

        /// Fraction d'objectif atteinte, bornée à [0, 1].
        public var progression: Double {
            objectifML > 0 ? min(1, Double(consomméML) / Double(objectifML)) : 0
        }

        /// Objectif du jour atteint.
        public var atteint: Bool { objectifML > 0 && consomméML >= objectifML }
    }

    public init() {}
}
