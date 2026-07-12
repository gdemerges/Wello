import SwiftUI
import UIKit
import WelloKit

// MARK: - Couleurs

extension Color {
    /// Initialise une couleur depuis un hex 0xRRGGBB.
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    /// Couleur adaptative clair/sombre.
    static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: 1)
    }
}

// MARK: - Thème

/// Palette et styles « eau / hydratation » de Wello.
/// Les 4 teintes d'accent sont thématisables (Wello+) : elles se lisent sur `current`, palette
/// active mutée par `ThemeStore`. Les neutres adaptatifs restent fixes (lisibilité clair/sombre).
enum WelloTheme {
    /// Thème actif. Posé par `ThemeStore` au démarrage (défaut `glacier` = palette historique).
    static var current: AppTheme = .glacier

    static var accent: Color { Color(hex: current.palette.accent) }          // bleu glacier (défaut)
    static var accentDeep: Color { Color(hex: current.palette.accentDeep) }
    static var waterTop: Color { Color(hex: current.palette.waterTop) }
    static var waterBottom: Color { Color(hex: current.palette.waterBottom) }

    /// « Objectif atteint » : la teinte profonde du thème, pas un vert système. Un jour réussi est
    /// un jour *plein* (couleur du thème saturée), pas un jour vert qui jure avec Aurore/Crépuscule.
    static var success: Color { accentDeep }

    /// Icône « récipient » selon le volume : on ne boit pas des gouttes mais des contenants — le
    /// symbole devient porteur d'information (« je finis ma gourde → je tape la gourde »).
    static func contenantIcône(pourML ml: Int) -> String {
        switch ml {
        case ..<220:    return "cup.and.saucer.fill"   // petit verre / tasse
        case 220..<400: return "mug.fill"              // grand verre / mug
        default:        return "waterbottle.fill"      // gourde
        }
    }

    static let canvas = Color.adaptive(light: 0xF2F9FF, dark: 0x0A141F)
    static let card = Color.adaptive(light: 0xFFFFFF, dark: 0x132231)
    static let ink = Color.adaptive(light: 0x0B2A4A, dark: 0xEAF6FF)
    static let inkSoft = Color.adaptive(light: 0x5B7790, dark: 0x9DB6CC)

    static var waterGradient: LinearGradient {
        LinearGradient(colors: [waterTop, waterBottom], startPoint: .top, endPoint: .bottom)
    }
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Élévation

/// Deux niveaux d'ombre nommés — pour tenir une échelle d'élévation cohérente au lieu de valeurs
/// ad hoc (boutons/lentille = `.basse`, cartes = `.haute`).
enum WelloElevation {
    case basse   // boutons, lentille de la jauge
    case haute   // cartes

    var radius: CGFloat { self == .basse ? 6 : 14 }
    var y: CGFloat { self == .basse ? 3 : 6 }
    var opacity: Double { 0.06 }
}

extension View {
    func welloElevation(_ e: WelloElevation) -> some View {
        shadow(color: .black.opacity(e.opacity), radius: e.radius, y: e.y)
    }
}

// MARK: - Fond d'écran

/// Fond standard : voile clair avec un halo bleu qui vit avec le moment de la journée — lumière
/// haute et froide le matin, zénith neutre, plus basse et légèrement chaude le soir. Amplitude
/// faible (opacité 0.10–0.16 + point d'ancrage) pour ne pas se battre avec les thèmes.
struct WelloBackground: ViewModifier {
    var période: DayPeriod = DayPeriod.from(hour: Calendar.current.component(.hour, from: .now))

    private var haloOpacité: Double {
        switch période {
        case .matin: 0.16   // lumière haute et présente
        case .midi:  0.10   // zénith neutre
        case .apresMidi: 0.12
        case .soiree: 0.11
        case .nuit:  0.10   // veilleuse discrète
        }
    }

    /// Point bas du halo : haut le matin, il descend au fil de la journée.
    private var haloBas: UnitPoint {
        switch période {
        case .matin: UnitPoint(x: 0.5, y: 0.42)
        case .midi:  .center
        case .apresMidi: UnitPoint(x: 0.5, y: 0.62)
        case .soiree, .nuit: UnitPoint(x: 0.5, y: 0.78)
        }
    }

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                WelloTheme.canvas
                LinearGradient(colors: [WelloTheme.accent.opacity(haloOpacité), .clear],
                               startPoint: .top, endPoint: haloBas)
                // Fin de journée : lueur chaude, basse et très ténue (n'écrase pas la palette active).
                if période == .soiree || période == .nuit {
                    LinearGradient(colors: [.clear, Color.orange.opacity(période == .soiree ? 0.06 : 0.03)],
                                   startPoint: .center, endPoint: .bottom)
                }
            }
            .ignoresSafeArea()
        )
    }
}

extension View {
    func welloBackground() -> some View { modifier(WelloBackground()) }
}

// MARK: - Composants réutilisables

/// Bouton d'ajout d'eau : pilule en dégradé clair qui se compresse et s'assombrit
/// brièvement à chaque tap. La pulsation est déclenchée par l'action (et non par
/// `isPressed`) pour rester visible même sur un clic instantané (simulateur).
struct WaterLogButton: View {
    let ml: Int
    let action: () async -> Void
    @State private var enfoncé = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.13, dampingFraction: 0.5)) { enfoncé = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(130))
                withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { enfoncé = false }
            }
            Task { await action() }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: WelloTheme.contenantIcône(pourML: ml)).font(.system(size: 16))
                Text("+\(ml)").font(.system(.headline, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
            }
            .foregroundStyle(WelloTheme.accentDeep)          // teinte accent, plus la jauge qui porte la saturation
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WelloTheme.accent.opacity(enfoncé ? 0.24 : 0.14),   // fond teinté doux, plus foncé au tap
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(enfoncé && !reduceMotion ? 0.92 : 1) // pas de scale si Reduce Motion
            .welloElevation(.basse)                          // affordance discrète (plus de halo saturé)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter \(ml) millilitres")
    }
}

/// Pastille « Autre » (contour) assortie aux WaterLogButton : ouvre la saisie ponctuelle.
struct WaterMorePill: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                Text("Autre").font(.system(.headline, design: .rounded))
            }
            .foregroundStyle(WelloTheme.accentDeep)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WelloTheme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(WelloTheme.accent.opacity(0.35), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter une autre quantité")
    }
}

/// Logo-texte « Wello » : goutte + mot rempli du dégradé eau, police arrondie lourde.
struct WelloWordmark: View {
    /// Taille suivant Dynamic Type (relative à Title 3).
    @ScaledMetric(relativeTo: .title3) private var size: CGFloat = 22
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "drop.fill")
                .font(.system(size: size * 0.78, weight: .bold))
            Text("Wello")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(0.5)
        }
        .foregroundStyle(WelloTheme.accentGradient)
        .accessibilityElement()
        .accessibilityLabel("Wello")
        .accessibilityAddTraits(.isHeader)
    }
}

/// Carte arrondie douce sur fond `card`.
struct CardContainer<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WelloTheme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .welloElevation(.haute)
    }
}

/// Panneau « voile » : le palier de matière SOUS la carte — teinté accent, plat, sans ombre.
/// La matière encode la hiérarchie : carte élevée = vivant/actionnable, voile = savoir de
/// référence, texte nu = méta. Évite l'écran « pile de cartes blanches équivalentes ».
struct VoilePanel<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WelloTheme.accent.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Dispose ses sous-vues en lignes avec retour automatique (comme un texte) : sert aux chips
/// de composantes de l'objectif et aux presets de quantité. Largeur pilotée par le parent.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let largeur = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, hauteurLigne: CGFloat = 0
        for sous in subviews {
            let taille = sous.sizeThatFits(.unspecified)
            if x > 0 && x + taille.width > largeur {
                x = 0
                y += hauteurLigne + spacing
                hauteurLigne = 0
            }
            x += taille.width + spacing
            hauteurLigne = max(hauteurLigne, taille.height)
        }
        return CGSize(width: largeur == .infinity ? max(0, x - spacing) : largeur,
                      height: y + hauteurLigne)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, hauteurLigne: CGFloat = 0
        for sous in subviews {
            let taille = sous.sizeThatFits(.unspecified)
            if x > bounds.minX && x + taille.width > bounds.maxX {
                x = bounds.minX
                y += hauteurLigne + spacing
                hauteurLigne = 0
            }
            sous.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += taille.width + spacing
            hauteurLigne = max(hauteurLigne, taille.height)
        }
    }
}
