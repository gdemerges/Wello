import Foundation
import WelloKit

/// Libellés localisés des enums `WelloKit` affichées en UI. WelloKit reste volontairement sans
/// dépendance de localisation (pur, testable en CLI) : `.label` y renvoie un texte français fixe,
/// utile aux tests/logs mais pas à l'affichage. La traduction se fait ici, côté app, avec
/// `String(localized:)` — même mécanisme que `NotificationService.corps` pour les rappels.
///
/// Important : passer une `String` (résultat de `.label`) à `Text(_:)` ou `Label(_:systemImage:)`
/// résout l'initialiseur *verbatim* (pas de recherche dans le catalogue), contrairement à un
/// littéral `Text("...")`. D'où le besoin de résoudre nous-mêmes la traduction en amont.
extension DrinkType {
    var libellé: String {
        switch self {
        case .water:     String(localized: "Eau")
        case .sparkling: String(localized: "Eau gazeuse")
        case .herbalTea: String(localized: "Tisane")
        case .milk:      String(localized: "Lait")
        case .tea:       String(localized: "Thé")
        case .coffee:    String(localized: "Café")
        case .juice:     String(localized: "Jus de fruits")
        case .soda:      String(localized: "Soda")
        case .energy:    String(localized: "Boisson énergisante")
        case .alcohol:   String(localized: "Alcool")
        case .beer:      String(localized: "Bière")
        case .wine:      String(localized: "Vin")
        case .spirits:   String(localized: "Spiritueux")
        }
    }
}

extension DrinkFamily {
    var libellé: String {
        switch self {
        case .water:    String(localized: "Eau")
        case .caffeine: String(localized: "Café / thé")
        case .alcohol:  String(localized: "Alcool")
        case .sweet:    String(localized: "Boissons sucrées")
        case .other:    String(localized: "Autres")
        }
    }
}

extension DayPeriod {
    var libellé: String {
        switch self {
        case .matin:     String(localized: "Matin")
        case .midi:      String(localized: "Midi")
        case .apresMidi: String(localized: "Après-midi")
        case .soiree:    String(localized: "Soirée")
        case .nuit:      String(localized: "Nuit")
        }
    }
}

extension AppTheme {
    /// Nommé différemment de `.label` (WelloKit) pour éviter toute ambiguïté sur l'appel voulu.
    var libelléLocalisé: String {
        switch self {
        case .glacier:    String(localized: "Glacier")
        case .aurore:     String(localized: "Aurore")
        case .menthe:     String(localized: "Menthe")
        case .crepuscule: String(localized: "Crépuscule")
        }
    }
}
