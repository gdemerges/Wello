import SwiftUI

/// Onboarding de premier lancement : 3 écrans (valeur, calcul, permissions).
struct OnboardingView: View {
    /// Appelé au tap final « Commencer ».
    let onTerminé: () -> Void
    @State private var page = 0
    /// Taille de l'illustration suivant Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var tailleIcône: CGFloat = 72

    private struct Page { let icon: String; let titre: String; let texte: String }
    private let pages = [
        Page(icon: "drop.fill",
             titre: "Bienvenue dans Wello",
             texte: "Ton suivi d'hydratation personnel, calculé pour toi et 100 % local sur ton iPhone."),
        Page(icon: "figure.run",
             titre: "Un objectif qui s'adapte",
             texte: "Wello ajuste ton objectif du jour selon ton poids, ton activité (Santé) et la météo — sans jamais descendre sous ton plancher médical."),
        Page(icon: "checkmark.shield.fill",
             titre: "Tes autorisations",
             texte: "Santé, localisation et notifications affinent le calcul et les rappels. Tout refus est géré : l'app reste pleinement utilisable en saisie manuelle."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageVue(pages[i]).tag(i)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onTerminé()
                }
            } label: {
                Text(page < pages.count - 1 ? "Suivant" : "Commencer")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(WelloTheme.accentGradient,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .welloBackground()
    }

    private func pageVue(_ p: Page) -> some View {
        VStack(spacing: 22) {
            Image(systemName: p.icon)
                .font(.system(size: tailleIcône, weight: .semibold))
                .foregroundStyle(WelloTheme.accentGradient)
                .accessibilityHidden(true)   // décorative : le titre/texte porte le sens
            Text(p.titre)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(WelloTheme.ink)
                .multilineTextAlignment(.center)
            Text(p.texte)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(WelloTheme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

#if DEBUG
#Preview {
    OnboardingView(onTerminé: {})
}
#endif
