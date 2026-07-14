import Foundation
import OSLog

/// Journalisation unifiée (`os.Logger`).
///
/// Wello n'a **aucune télémétrie** : rien ne quitte l'appareil sans un geste explicite de
/// l'utilisateur. La contrepartie, c'est qu'une panne silencieuse (HealthKit refusé, météo qui
/// échoue, réveil en arrière-plan coupé par le système, achat qui ne se restaure pas) ne laissait
/// jusqu'ici **aucune trace** : les services avalaient leurs erreurs. Ces journaux ne sont pas
/// envoyés — ils rendent simplement diagnosticable, dans Console.app ou un sysdiagnose, ce qu'un
/// utilisateur décrit vaguement (« la météo ne marche pas »).
///
/// Règle de confidentialité : les messages restent **factuels et non identifiants**. On journalise
/// des causes (« refus d'autorisation », « HTTP 503 »), jamais une position, un volume bu ou une
/// donnée de santé. Les interpolations sensibles doivent rester `private` (défaut d'`os.Logger`),
/// et seul ce qui est anodin est marqué `.public`.
enum WelloLog {
    private static let sujet = "Life.Wello"

    /// Cycle de vie de l'app et réveils en arrière-plan (le plus utile en prod : c'est là qu'on
    /// voit si HealthKit nous réveille vraiment, ou s'il a coupé la livraison).
    static let app = Logger(subsystem: sujet, category: "app")
    /// Lectures/écritures HealthKit et observation en arrière-plan.
    static let santé = Logger(subsystem: sujet, category: "sante")
    /// Localisation et appels Open-Meteo.
    static let météo = Logger(subsystem: sujet, category: "meteo")
    /// Planification des rappels locaux.
    static let rappels = Logger(subsystem: sujet, category: "rappels")
    /// StoreKit : produits, achats, restauration, entitlement.
    static let achats = Logger(subsystem: sujet, category: "achats")
    /// SwiftData : lectures, écritures, effacement.
    static let données = Logger(subsystem: sujet, category: "donnees")
}
