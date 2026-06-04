/// Sexe biologique, base physiologique du besoin en eau (apports de référence EFSA 2010).
public enum BiologicalSex: String, Sendable, CaseIterable {
    case homme
    case femme
    /// Libellé court français pour l'affichage.
    public var label: String { self == .homme ? "Homme" : "Femme" }
}
