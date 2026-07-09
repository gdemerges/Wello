import Testing
@testable import WelloKit

@Suite("BilanHebdomadaire")
struct BilanHebdomadaireTests {
    /// Jour atteint (2000/2000) ou non (1000/2000).
    func atteint(_ ok: Bool) -> DailyTotal {
        DailyTotal(consumedML: ok ? 2000 : 1000, goalML: 2000)
    }

    @Test("Aucun jour → nil")
    func vide() {
        #expect(BilanHebdomadaire.calculer(joursRécents: []) == nil)
    }

    @Test("Compte les jours atteints de la semaine")
    func joursAtteints() {
        let jours = [atteint(true), atteint(true), atteint(false), atteint(true),
                     atteint(false), atteint(true), atteint(true)]
        let b = BilanHebdomadaire.calculer(joursRécents: jours)
        #expect(b?.joursAtteints == 5)
        #expect(b?.joursComptés == 7)
    }

    @Test("Sans semaine précédente : pas de comparaison, tendance stable")
    func sansComparaison() {
        let b = BilanHebdomadaire.calculer(joursRécents: Array(repeating: atteint(true), count: 5))
        #expect(b?.aComparaison == false)
        #expect(b?.deltaML == 0)
        #expect(b?.tendance == .stable)
    }

    @Test("Hausse détectée vs semaine précédente")
    func hausse() {
        // Semaine courante 2000 ml de moyenne, précédente 1500 → +500.
        let courante = Array(repeating: DailyTotal(consumedML: 2000, goalML: 2000), count: 7)
        let précédente = Array(repeating: DailyTotal(consumedML: 1500, goalML: 2000), count: 7)
        let b = BilanHebdomadaire.calculer(joursRécents: courante + précédente)
        #expect(b?.aComparaison == true)
        #expect(b?.deltaML == 500)
        #expect(b?.tendance == .hausse)
    }

    @Test("Baisse détectée")
    func baisse() {
        let courante = Array(repeating: DailyTotal(consumedML: 1400, goalML: 2000), count: 7)
        let précédente = Array(repeating: DailyTotal(consumedML: 2000, goalML: 2000), count: 7)
        let b = BilanHebdomadaire.calculer(joursRécents: courante + précédente)
        #expect(b?.tendance == .baisse)
        #expect(b?.deltaML == -600)
    }

    @Test("Écart faible → stable (sous le seuil)")
    func stable() {
        let courante = Array(repeating: DailyTotal(consumedML: 2000, goalML: 2000), count: 7)
        let précédente = Array(repeating: DailyTotal(consumedML: 1980, goalML: 2000), count: 7)
        let b = BilanHebdomadaire.calculer(joursRécents: courante + précédente)
        #expect(b?.tendance == .stable)   // 20 ml < seuil 50
    }
}
