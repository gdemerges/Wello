/// Palette de teintes d'un thème (hex 0xRRGGBB). Pure : aucune dépendance SwiftUI/UIKit,
/// pour rester testable en CLI et partageable. Le côté app convertit en `Color`.
public struct ThemePalette: Sendable, Equatable {
    public let accent: UInt
    public let accentDeep: UInt
    public let waterTop: UInt
    public let waterBottom: UInt

    public init(accent: UInt, accentDeep: UInt, waterTop: UInt, waterBottom: UInt) {
        self.accent = accent
        self.accentDeep = accentDeep
        self.waterTop = waterTop
        self.waterBottom = waterBottom
    }
}

/// Thème de couleur de l'app (teinte d'accent + dégradé d'eau). Réservé à Wello+ sauf `glacier`.
/// Le gating passe par `PremiumFeature.themes`. Raw values **stables** : ils persistent en
/// `UserDefaults` côté app — ne pas les renommer.
public enum AppTheme: String, Sendable, CaseIterable, Identifiable {
    /// Thème par défaut, gratuit : la palette historique de Wello (bleu glacier).
    case glacier
    /// Corail chaud (lever de soleil).
    case aurore
    /// Vert d'eau (menthe).
    case menthe
    /// Indigo / violet (crépuscule).
    case crepuscule

    public var id: String { rawValue }

    /// Libellé court francophone pour l'affichage.
    public var label: String {
        switch self {
        case .glacier:    return "Glacier"
        case .aurore:     return "Aurore"
        case .menthe:     return "Menthe"
        case .crepuscule: return "Crépuscule"
        }
    }

    /// Seul le thème par défaut est gratuit ; les autres sont réservés à Wello+.
    public var estGratuit: Bool { self == .glacier }

    /// Teintes du thème. `glacier` reprend exactement la palette actuelle de l'app.
    public var palette: ThemePalette {
        switch self {
        case .glacier:
            return ThemePalette(accent: 0x4FB0E5, accentDeep: 0x2E8BC9,
                                waterTop: 0x86D7F5, waterBottom: 0x3FA3E0)
        case .aurore:
            return ThemePalette(accent: 0xFF8FA3, accentDeep: 0xE85D75,
                                waterTop: 0xFFB3C1, waterBottom: 0xF87890)
        case .menthe:
            return ThemePalette(accent: 0x4FD0A8, accentDeep: 0x2EA888,
                                waterTop: 0x86F5D7, waterBottom: 0x3FE0B0)
        case .crepuscule:
            return ThemePalette(accent: 0x8B7FE5, accentDeep: 0x6B5DC9,
                                waterTop: 0xB3A8F5, waterBottom: 0x8878E0)
        }
    }

    /// Nom de l'asset d'icône alternative ; `nil` = icône primaire (thème `glacier`).
    public var alternateIconName: String? {
        switch self {
        case .glacier:    return nil
        case .aurore:     return "AppIcon-Aurore"
        case .menthe:     return "AppIcon-Menthe"
        case .crepuscule: return "AppIcon-Crepuscule"
        }
    }
}
