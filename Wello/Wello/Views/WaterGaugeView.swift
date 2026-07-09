import SwiftUI

/// Vague sinusoïdale remplissant la forme selon `progress` (0…1). `phase` (piloté image par
/// image par un `TimelineView`) décale la crête ; `frequency` = nombre de crêtes sur la largeur
/// (permet de superposer deux ondes décorrélées).
///
/// Seul `progress` est *animable* (montée « ressort » du niveau) : `phase` est recalculé à
/// chaque image et ne doit donc pas s'interpoler, sinon les deux mouvements se marchent dessus.
struct WaterWave: Shape {
    var progress: Double
    var phase: Double
    var amplitude: Double = 7
    var frequency: Double = 1

    // `progress` (montée du niveau) ET `amplitude` (gonflement de célébration) sont animables ;
    // `phase` reste hors animation — recalculée à chaque image, elle ne doit pas s'interpoler.
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, amplitude) }
        set { progress = newValue.first; amplitude = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let niveau = rect.height * (1 - progress)
        path.move(to: CGPoint(x: 0, y: niveau))
        var x: CGFloat = 0
        while x <= rect.width {
            let relatif = Double(x / max(rect.width, 1))
            let y = niveau + amplitude * sin(relatif * 2 * .pi * frequency + phase)
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

/// Jauge circulaire « verre d'eau » : le niveau monte avec la progression. Deux vagues
/// superposées + ligne de surface (ménisque) donnent le mouvement d'un liquide ; un rim
/// éclairé en haut simule le verre, et une lentille givrée au centre garantit la lisibilité
/// du compteur quelle que soit la hauteur d'eau derrière lui.
struct WaterGaugeView: View {
    let consomméML: Int
    let objectifML: Int
    /// Anime la vague seulement quand la jauge est réellement visible (onglet actif) →
    /// pas de rendu par frame gaspillé sur les onglets en arrière-plan (TabView les garde vivants).
    var animer: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Taille du compteur suivant Dynamic Type (bornée par minimumScaleFactor côté affichage).
    /// Sans le « % » redondant, le chiffre qui compte peut respirer.
    @ScaledMetric(relativeTo: .largeTitle) private var tailleNombre: CGFloat = 58
    /// Période d'un cycle complet de la vague (secondes).
    private let période = 2.4
    /// Intensité de la célébration d'objectif (0 = repos, 1 = pic) : la surface gonfle puis s'apaise,
    /// le ménisque s'illumine et le compteur passe en teinte accent. La fête a lieu *dans* l'eau.
    @State private var fêteIntensité: Double = 0

    private var progress: Double {
        guard objectifML > 0 else { return 0 }
        return min(Double(consomméML) / Double(objectifML), 1)
    }
    private var pourcentage: Int { Int((progress * 100).rounded()) }
    private var objectifAtteint: Bool { objectifML > 0 && consomméML >= objectifML }

    /// Rim de verre : liseré clair en haut fondu vers l'accent en bas → volume. À l'objectif atteint
    /// il s'éclaire vers l'accent (seul effet conservé sous Reduce Motion : « fondu du rim »).
    private var rimGradient: LinearGradient {
        LinearGradient(colors: [.white.opacity(0.55 + fêteIntensité * 0.3),
                                WelloTheme.accent.opacity(0.22 + fêteIntensité * 0.5)],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        // Vague figée (mais toujours dessinée) si Reduce Motion est actif OU jauge hors-écran.
        TimelineView(.animation(paused: reduceMotion || !animer)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = (reduceMotion || !animer) ? 0 : (t.truncatingRemainder(dividingBy: période) / période) * 2 * .pi
            contenu(phase: phase)
        }
        .containerRelativeFrame(.horizontal) { largeur, _ in min(largeur * 0.68, 280) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hydratation du jour")
        .accessibilityValue("\(consomméML) millilitres sur \(objectifML), \(pourcentage) pour cent")
        // La célébration se déclenche au franchissement de l'objectif (pas à chaque rendu déjà atteint).
        .onChange(of: objectifAtteint) { _, atteint in if atteint { célébrer() } }
    }

    /// Anime la montée d'intensité puis son apaisement. Sous Reduce Motion, seules les propriétés
    /// dérivées non-cinétiques bougent (rim/ménisque/compteur se teintent) — pas de gonflement de vague.
    private func célébrer() {
        let montée: Animation = reduceMotion ? .easeInOut(duration: 0.3) : .spring(response: 0.3, dampingFraction: 0.5)
        withAnimation(montée) { fêteIntensité = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 400 : 550))
            withAnimation(.easeOut(duration: reduceMotion ? 0.4 : 1.0)) { fêteIntensité = 0 }
        }
    }

    private func contenu(phase: Double) -> some View {
        // Gonflement de la surface au moment de la célébration (nul sous Reduce Motion).
        let boost = reduceMotion ? 0 : fêteIntensité * 8
        return ZStack {
            // Puits vide, légèrement teinté.
            Circle().fill(WelloTheme.accent.opacity(0.08))

            // Eau : vague arrière décorrélée + vague avant + ménisque de surface, clippées au cercle.
            ZStack {
                WaterWave(progress: progress, phase: phase * 0.8 + .pi, amplitude: 5 + boost * 0.6, frequency: 1.6)
                    .fill(WelloTheme.waterGradient)
                    .opacity(0.5)
                WaterWave(progress: progress, phase: phase, amplitude: 8 + boost)
                    .fill(WelloTheme.waterGradient)
                    .opacity(0.95)
                WaterWave(progress: progress, phase: phase, amplitude: 8 + boost)
                    .stroke(.white.opacity(0.45 + fêteIntensité * 0.5), lineWidth: 1.5)   // ménisque : s'illumine à l'objectif
            }
            .clipShape(Circle())

            // Verre : rim éclairé en haut.
            Circle().strokeBorder(rimGradient, lineWidth: 2.5 + fêteIntensité * 1.5)

            // Lentille de lecture givrée : contraste garanti sur l'eau à tout niveau de remplissage.
            // Lentille de lecture : le « % » est retiré (le niveau d'eau *est* le pourcentage — il
            // reste dans `accessibilityValue`), le chiffre qui compte gagne en présence.
            VStack(spacing: 2) {
                Text("\(consomméML)")
                    .font(.system(size: tailleNombre, weight: .bold, design: .rounded))
                    .foregroundStyle(fêteIntensité > 0.35 ? WelloTheme.accentDeep : WelloTheme.ink)  // teinte accent à l'objectif
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("/ \(objectifML) ml")
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .foregroundStyle(WelloTheme.inkSoft)
            }
            .padding(24)
            .frame(width: 150, height: 150)
            // Disque translucide *solide* (pas de backdrop blur) : même contraste garanti sur
            // l'eau, sans re-flouter le fond animé à chaque image (coût GPU/batterie évité).
            .background(WelloTheme.card.opacity(0.88), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .welloElevation(.basse)
        }
        // Montée « ressort » du niveau d'eau à chaque ajout ; instantanée si Reduce Motion.
        .animation(reduceMotion ? nil : .spring(response: 0.8, dampingFraction: 0.82), value: progress)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 40) {
        WaterGaugeView(consomméML: 1250, objectifML: 2730)
        WaterGaugeView(consomméML: 2730, objectifML: 2730)
    }
    .padding()
    .welloBackground()
}
#endif
