import Testing
@testable import WelloKit

@Suite("GénérateurInsights")
struct GénérateurInsightsTests {

    /// Construit une répartition (ml par tranche) dans l'ordre canonique.
    func répartition(matin: Int, midi: Int, aprèsMidi: Int, soirée: Int, nuit: Int)
        -> [(period: DayPeriod, ml: Int)] {
        [(.matin, matin), (.midi, midi), (.apresMidi, aprèsMidi), (.soiree, soirée), (.nuit, nuit)]
    }

    @Test("Trop peu de données → aucun insight")
    func pasAssez() {
        let r = répartition(matin: 200, midi: 100, aprèsMidi: 100, soirée: 100, nuit: 0)
        #expect(GénérateurInsights.analyser(r).isEmpty)   // total 500 < 3000
    }

    @Test("Pic du matin détecté")
    func picMatin() {
        let r = répartition(matin: 2000, midi: 800, aprèsMidi: 700, soirée: 500, nuit: 0)
        let insights = GénérateurInsights.analyser(r)
        #expect(insights.contains { $0.genre == .pic && $0.période == .matin })
    }

    @Test("Après-midi en creux détecté")
    func creuxAprèsMidi() {
        // total 4000, après-midi 200 = 5 % < 12 %.
        let r = répartition(matin: 1500, midi: 1300, aprèsMidi: 200, soirée: 1000, nuit: 0)
        let insights = GénérateurInsights.analyser(r)
        #expect(insights.contains { $0.genre == .creux && $0.période == .apresMidi })
    }

    @Test("Profil tardif quand soirée+nuit dominent")
    func tardif() {
        let r = répartition(matin: 500, midi: 500, aprèsMidi: 500, soirée: 1500, nuit: 1000)
        let insights = GénérateurInsights.analyser(r)
        #expect(insights.contains { $0.genre == .tardif })
    }

    @Test("Tardif n'ajoute pas un pic « soirée » redondant")
    func pasDeRedondance() {
        let r = répartition(matin: 300, midi: 300, aprèsMidi: 300, soirée: 2000, nuit: 800)
        let insights = GénérateurInsights.analyser(r)
        #expect(insights.contains { $0.genre == .tardif })
        #expect(!insights.contains { $0.genre == .pic && $0.période == .soiree })
    }

    @Test("Répartition équilibrée → insight « équilibré »")
    func équilibré() {
        let r = répartition(matin: 900, midi: 850, aprèsMidi: 850, soirée: 900, nuit: 0)
        let insights = GénérateurInsights.analyser(r)
        #expect(insights == [Insight(genre: .équilibré, période: nil)])
    }

    @Test("Au plus deux enseignements")
    func plafond() {
        let r = répartition(matin: 3000, midi: 100, aprèsMidi: 100, soirée: 1800, nuit: 1200)
        #expect(GénérateurInsights.analyser(r).count <= 2)
    }
}
