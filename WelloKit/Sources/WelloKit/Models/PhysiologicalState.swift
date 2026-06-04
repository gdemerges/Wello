/// État physiologique influant sur le besoin en eau (apports additifs EFSA).
/// Exclusif : on est soit dans aucun de ces états, soit dans un seul.
public enum PhysiologicalState: String, Sendable, CaseIterable {
    case aucun
    case grossesse
    case allaitement

    /// Apport additif quotidien d'eau de boisson (ml), valeurs EFSA.
    /// Grossesse : +300 ml. Allaitement : +700 ml (borne haute de 600–700).
    public var bonusML: Int {
        switch self {
        case .aucun:       0
        case .grossesse:   300
        case .allaitement: 700
        }
    }

    /// Libellé court français pour l'affichage.
    public var label: String {
        switch self {
        case .aucun:       "Aucun"
        case .grossesse:   "Enceinte"
        case .allaitement: "Allaitante"
        }
    }
}
