import Testing
@testable import WelloKit

@Suite("RappelRédacteur")
struct RappelRédacteurTests {
    let rédacteur = RappelRédacteur()
    // Fenêtre standard 7h–21h (840 min de span).
    let fenêtre = FenêtreÉveil(réveilMin: 7 * 60, coucherMin: 21 * 60)

    @Test("Le restant n'est jamais négatif")
    func restantBorné() {
        let m = rédacteur.message(heureRappelMin: 12 * 60, objectifML: 2000,
                                  consomméML: 2500, fenêtre: fenêtre)
        #expect(m.restantML == 0)
    }

    @Test("Restant = objectif − consommé")
    func restantCalculé() {
        let m = rédacteur.message(heureRappelMin: 12 * 60, objectifML: 2000,
                                  consomméML: 800, fenêtre: fenêtre)
        #expect(m.restantML == 1200)
    }

    @Test("Le moment de la journée suit l'heure du rappel")
    func momentSelonHeure() {
        #expect(RappelRédacteur.moment(8 * 60) == .matin)
        #expect(RappelRédacteur.moment(12 * 60) == .midi)
        #expect(RappelRédacteur.moment(16 * 60) == .aprèsMidi)
        #expect(RappelRédacteur.moment(20 * 60) == .soir)
    }

    @Test("En avance : consommé au-dessus du rythme attendu")
    func enAvance() {
        // À mi-fenêtre (14h), rythme attendu ≈ 50 % = 1000 ml ; 1400 ml → en avance.
        let m = rédacteur.message(heureRappelMin: 14 * 60, objectifML: 2000,
                                  consomméML: 1400, fenêtre: fenêtre)
        #expect(m.ton == .enAvance)
    }

    @Test("Dans les temps : consommé proche du rythme attendu")
    func dansLesTemps() {
        // À mi-fenêtre, attendu ≈ 1000 ml ; 1000 ml → pile dans les temps.
        let m = rédacteur.message(heureRappelMin: 14 * 60, objectifML: 2000,
                                  consomméML: 1000, fenêtre: fenêtre)
        #expect(m.ton == .dansLesTemps)
    }

    @Test("En retard : léger déficit sur le rythme")
    func enRetard() {
        // Attendu ≈ 1000 ml ; 700 ml → déficit -15 % → en retard.
        let m = rédacteur.message(heureRappelMin: 14 * 60, objectifML: 2000,
                                  consomméML: 700, fenêtre: fenêtre)
        #expect(m.ton == .enRetard)
    }

    @Test("Gros retard : déficit marqué sur le rythme")
    func grosRetard() {
        // Attendu ≈ 1000 ml ; 300 ml → déficit -35 % → gros retard.
        let m = rédacteur.message(heureRappelMin: 14 * 60, objectifML: 2000,
                                  consomméML: 300, fenêtre: fenêtre)
        #expect(m.ton == .grosRetard)
    }

    @Test("Tôt le matin, ne rien avoir bu reste « dans les temps »")
    func matinPasDeRetard() {
        // À 8h, attendu ≈ 7 % ; 0 ml → déficit faible, pas de faux « retard ».
        let m = rédacteur.message(heureRappelMin: 8 * 60, objectifML: 2000,
                                  consomméML: 0, fenêtre: fenêtre)
        #expect(m.ton == .dansLesTemps || m.ton == .enRetard)
        #expect(m.moment == .matin)
    }

    @Test("Le soir, ne presque rien avoir bu = gros retard")
    func soirGrosRetard() {
        // À 20h, attendu ≈ 93 % ; 400 ml → gros retard.
        let m = rédacteur.message(heureRappelMin: 20 * 60, objectifML: 2000,
                                  consomméML: 400, fenêtre: fenêtre)
        #expect(m.ton == .grosRetard)
        #expect(m.moment == .soir)
    }
}
