import Testing
@testable import WelloKit

@Suite("StreakMilestone")
struct StreakMilestoneTests {

    @Test("Un palier exact est reconnu")
    func palierExact() {
        #expect(StreakMilestone.palier(pour: 7) == 7)
        #expect(StreakMilestone.palier(pour: 30) == 30)
        #expect(StreakMilestone.palier(pour: 365) == 365)
    }

    @Test("Hors palier renvoie nil")
    func horsPalier() {
        #expect(StreakMilestone.palier(pour: 0) == nil)
        #expect(StreakMilestone.palier(pour: 1) == nil)
        #expect(StreakMilestone.palier(pour: 8) == nil)
        #expect(StreakMilestone.palier(pour: 31) == nil)
    }

    @Test("Les paliers sont strictement croissants")
    func paliersOrdonnés() {
        let p = StreakMilestone.paliers
        #expect(p == p.sorted())
        #expect(Set(p).count == p.count)
    }
}
