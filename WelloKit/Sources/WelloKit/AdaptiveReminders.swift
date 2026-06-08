import Foundation

/// Fenêtre d'éveil quotidienne, en minutes depuis minuit.
public struct FenêtreÉveil: Sendable, Equatable {
    public let réveilMin: Int
    public let coucherMin: Int
    public init(réveilMin: Int, coucherMin: Int) {
        self.réveilMin = réveilMin
        self.coucherMin = coucherMin
    }
    /// Repli ultime quand ni le sommeil ni l'historique ne renseignent la fenêtre.
    public static let défaut = FenêtreÉveil(réveilMin: 7 * 60, coucherMin: 21 * 60)
}

/// Un intervalle de sommeil (source HealthKit, mappé en type pur pour la dérivation testable).
public struct PériodeSommeil: Sendable {
    public let début: Date
    public let fin: Date
    public init(début: Date, fin: Date) {
        self.début = début
        self.fin = fin
    }
}

/// Les prises d'un jour, en minutes depuis minuit (ordre indifférent ; trié à l'usage).
public struct JourDePrises: Sendable {
    public let minutesDePrise: [Int]
    public init(minutesDePrise: [Int]) {
        self.minutesDePrise = minutesDePrise
    }
}

/// Planificateur pur des rappels adaptatifs : apprend les trous d'hydratation récurrents
/// et en déduit des heures de rappel préventives. Aucune dépendance UIKit/HealthKit →
/// entièrement testable via `swift test`.
public struct AdaptiveReminderPlanner: Sendable {
    // Constantes de réglage (documentées, ajustables sans toucher la logique).
    /// Fenêtre d'apprentissage glissante.
    public static let joursHistoire = 14
    /// Données minimales avant d'activer l'adaptatif (sinon rappels fixes).
    public static let minJoursPourAdaptatif = 7
    /// Durée minimale d'un « trou » d'hydratation (minutes).
    static let minGapMin = 120
    /// Fraction des jours où un créneau doit apparaître pour être « habituel ».
    static let seuilRécurrence = 0.40
    /// Anticipation : on rappelle ce nombre de minutes avant d'atteindre le seuil de trou.
    static let leadTimeMin = 15
    /// Espacement minimal entre deux rappels d'une même journée (minutes).
    static let espacementMin = 90
    /// Nombre maximal de rappels adaptatifs par jour.
    public static let plafondParJour = 6

    public init() {}

    /// Vrai si l'historique contient assez de jours non vides pour apprendre.
    public func aAssezDeDonnées(_ historique: [JourDePrises]) -> Bool {
        historique.filter { !$0.minutesDePrise.isEmpty }.count >= Self.minJoursPourAdaptatif
    }
}
