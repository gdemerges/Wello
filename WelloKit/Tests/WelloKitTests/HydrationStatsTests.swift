import Testing
@testable import WelloKit

@Suite("HydrationStats")
struct HydrationStatsTests {

    private func jour(_ bu: Int, _ obj: Int) -> DailyTotal { DailyTotal(consumedML: bu, goalML: obj) }

    @Test("Série : jours atteints consécutifs depuis le plus récent")
    func sérieNominale() {
        // récent → ancien : atteint, atteint, raté, atteint
        let days = [jour(2600, 2500), jour(2500, 2500), jour(1000, 2500), jour(3000, 2500)]
        #expect(HydrationStats.currentStreak(days) == 2)
    }

    @Test("Série : tous atteints")
    func sérieComplète() {
        let days = [jour(2600, 2500), jour(2700, 2500), jour(2500, 2500)]
        #expect(HydrationStats.currentStreak(days) == 3)
    }

    @Test("Série : le jour le plus récent raté → 0")
    func sérieRompue() {
        let days = [jour(1000, 2500), jour(2600, 2500)]
        #expect(HydrationStats.currentStreak(days) == 0)
    }

    @Test("Série : liste vide → 0")
    func sérieVide() {
        #expect(HydrationStats.currentStreak([]) == 0)
    }

    @Test("Moyenne sur les N derniers jours")
    func moyenne() {
        let days = [jour(3000, 2500), jour(2000, 2500), jour(1000, 2500), jour(4000, 2500)]
        #expect(HydrationStats.averageConsumed(days, lastN: 3) == 2000)   // (3000+2000+1000)/3
        #expect(HydrationStats.averageConsumed(days, lastN: 10) == 2500)  // (3000+2000+1000+4000)/4
        #expect(HydrationStats.averageConsumed([], lastN: 7) == 0)
    }
}
