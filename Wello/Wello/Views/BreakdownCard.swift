import SwiftUI
import WelloKit

/// Panneau « voile » détaillant la composition de l'objectif du jour (100 % additif) : le total
/// en tête, puis les termes rendus littéraux — des **chips qui s'additionnent**. Chaque chip est
/// tappable et ouvre l'explication sourcée de la composante (« Méthode »). Compact : ~3 lignes au
/// lieu de 8 rangées de 44 pt, sans rien perdre des affordances.
struct BreakdownCard: View {
    let breakdown: GoalBreakdown
    /// Vrai si la météo n'a pas pu être récupérée (le bonus à 0 n'est alors pas significatif).
    var météoIndisponible: Bool = false
    /// Libellé de la ligne état physiologique (selon l'état actif). nil si aucun.
    var libelléÉtatPhysio: String? = nil

    /// Composante dont l'explication est affichée en feuille (nil = aucune).
    @State private var détail: Composante?
    /// Présente l'écran « Méthode » complet.
    @State private var méthode = false

    var body: some View {
        VoilePanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Objectif du jour")
                        .font(.welloEntête)
                        .foregroundStyle(WelloTheme.ink)
                    Spacer()
                    Text("\(breakdown.totalML) ml")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(WelloTheme.accentDeep)
                }
                .accessibilityElement(children: .combine)

                // Termes additifs en chips (base + bonus, dans l'ordre ; optionnels masqués si nuls).
                FlowLayout(spacing: 8) {
                    chip(.base, "Base (EFSA)", breakdown.baseML)
                    chip(.activité, "Activité", breakdown.activityBonusML, signe: "+")
                    chip(.météo, "Météo", breakdown.weatherBonusML, signe: "+")
                    if breakdown.altitudeBonusML > 0 {
                        chip(.altitude, "Altitude", breakdown.altitudeBonusML, signe: "+")
                    }
                    if breakdown.lifeStageBonusML > 0 {
                        chip(.physiologie, libelléÉtatPhysioKey, breakdown.lifeStageBonusML, signe: "+")
                    }
                    if breakdown.renalBonusML > 0 {
                        chip(.rénal, "Besoin rénal", breakdown.renalBonusML, signe: "+")
                    }
                    if breakdown.bodyBonusML != 0 {
                        // Valeur négative : le "-" est déjà porté par l'entier.
                        chip(.corpulence, "Corpulence", breakdown.bodyBonusML,
                             signe: breakdown.bodyBonusML > 0 ? "+" : "")
                    }
                    if breakdown.manualAdjustmentML != 0 {
                        chip(.réglage, "Réglage avancé", breakdown.manualAdjustmentML,
                             signe: breakdown.manualAdjustmentML > 0 ? "+" : "")
                    }
                }

                if météoIndisponible {
                    badge("Météo indisponible — bonus non appliqué", "wifi.slash", .gray)
                }
                if breakdown.plafondAppliqué {
                    badge("Bridé au plafond de sécurité (4000 ml)", "exclamationmark.shield.fill", .orange)
                }

                Button {
                    méthode = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                        Text("Comment mon objectif est-il calculé ?")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(WelloTheme.accentDeep)
                    .frame(minHeight: 44)
                }
                .accessibilityHint("Ouvre l'explication détaillée du calcul")
            }
        }
        .sheet(item: $détail) { ComposanteDetailView(composante: $0) }
        .sheet(isPresented: $méthode) { MéthodeView() }
    }

    /// Libellé de la ligne physio en `LocalizedStringKey` (l'état actif, ou un défaut générique).
    private var libelléÉtatPhysioKey: LocalizedStringKey {
        libelléÉtatPhysio.map { LocalizedStringKey($0) } ?? "État physiologique"
    }

    /// Un terme de l'objectif en chip tappable → ouvre l'explication sourcée de la composante.
    /// Icône et teinte proviennent de la composante (cohérence avec la feuille de détail).
    private func chip(_ composante: Composante, _ libellé: LocalizedStringKey, _ valeur: Int,
                      signe: String = "") -> some View {
        Button {
            détail = composante
        } label: {
            HStack(spacing: 5) {
                Image(systemName: composante.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(composante.teinte)
                    .accessibilityHidden(true)
                Text(libellé)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(WelloTheme.ink)
                Text("\(signe)\(valeur)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(composante.teinte)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(WelloTheme.card.opacity(0.9), in: Capsule())
            .overlay(Capsule().strokeBorder(composante.teinte.opacity(0.25), lineWidth: 1))
            // Zone tactile étendue au-delà de la capsule (petite visuellement, ≥ 44 pt au doigt).
            .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        // Un seul élément VoiceOver par chip : « Base (EFSA), 2000 ml » plutôt que deux swipes.
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(signe)\(valeur) ml")
        .accessibilityHint("Voir l'explication")
    }

    private func badge(_ texte: LocalizedStringKey, _ icon: String, _ teinte: Color) -> some View {
        Label(texte, systemImage: icon)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(teinte)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(teinte.opacity(0.12), in: Capsule())
    }
}

#if DEBUG
#Preview {
    BreakdownCard(breakdown: GoalBreakdown(baseML: 1600, activityBonusML: 200, weatherBonusML: 300,
                                           altitudeBonusML: 150, lifeStageBonusML: 700, renalBonusML: 0,
                                           bodyBonusML: 200, totalML: 3150,
                                           plafondAppliqué: false),
                  libelléÉtatPhysio: "Allaitement")
    .padding()
    .welloBackground()
}
#endif
