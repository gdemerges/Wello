import Foundation

/// Moment de la journée d'un rappel, pour teinter le ton du message.
public enum MomentJournée: Sendable, Equatable {
    case matin, midi, aprèsMidi, soir
}

/// Jugement de rythme : où en est l'utilisateur par rapport au rythme *attendu*
/// à l'heure du rappel (progression linéaire sur la fenêtre d'éveil).
public enum TonRappel: Sendable, Equatable {
    /// En avance sur le rythme attendu.
    case enAvance
    /// Dans les temps (à ± un cheveu du rythme attendu).
    case dansLesTemps
    /// Un peu en dessous du rythme.
    case enRetard
    /// Nettement en dessous du rythme.
    case grosRetard
}

/// Description sémantique d'un rappel — *pas* le texte final. L'app la traduit en
/// chaîne localisée. Garder WelloKit sans dépendance de localisation et testable.
public struct MessageRappel: Sendable, Equatable {
    public let moment: MomentJournée
    public let ton: TonRappel
    /// Millilitres restants pour atteindre l'objectif (jamais négatif).
    public let restantML: Int
    public init(moment: MomentJournée, ton: TonRappel, restantML: Int) {
        self.moment = moment
        self.ton = ton
        self.restantML = restantML
    }
}

/// Rédige (sémantiquement) un rappel adapté au moment de la journée et au retard réel
/// sur le rythme attendu. Logique pure → testable via `swift test`.
///
/// Le rythme attendu est une montée linéaire de l'objectif sur la fenêtre d'éveil :
/// à mi-journée éveillée on « devrait » avoir bu ~50 % de l'objectif. On compare le
/// consommé connu au moment du planning à ce rythme pour choisir le ton.
public struct RappelRédacteur: Sendable {
    /// Seuil (fraction de l'objectif) au-delà duquel on considère l'utilisateur en avance.
    static let seuilAvance = 0.05
    /// En deçà de ce déficit relatif, on reste « dans les temps ».
    static let seuilRetard = -0.10
    /// En deçà, le retard devient « gros ».
    static let seuilGrosRetard = -0.25

    public init() {}

    public func message(heureRappelMin: Int, objectifML: Int,
                        consomméML: Int, fenêtre: FenêtreÉveil) -> MessageRappel {
        let restant = max(0, objectifML - consomméML)
        let moment = Self.moment(heureRappelMin)

        // Fraction de l'objectif attendue à l'heure du rappel (rythme linéaire).
        let span = max(1, fenêtre.coucherMin - fenêtre.réveilMin)
        let fracBrute = Double(heureRappelMin - fenêtre.réveilMin) / Double(span)
        let frac = min(max(fracBrute, 0), 1)
        let attenduML = Double(objectifML) * frac

        // Écart relatif : positif = en avance, négatif = en retard.
        let objectif = max(1, objectifML)
        let ratio = (Double(consomméML) - attenduML) / Double(objectif)

        let ton: TonRappel
        if ratio >= Self.seuilAvance {
            ton = .enAvance
        } else if ratio > Self.seuilRetard {
            ton = .dansLesTemps
        } else if ratio > Self.seuilGrosRetard {
            ton = .enRetard
        } else {
            ton = .grosRetard
        }

        return MessageRappel(moment: moment, ton: ton, restantML: restant)
    }

    static func moment(_ min: Int) -> MomentJournée {
        switch min {
        case ..<(11 * 60): return .matin
        case ..<(14 * 60): return .midi
        case ..<(18 * 60): return .aprèsMidi
        default: return .soir
        }
    }
}
