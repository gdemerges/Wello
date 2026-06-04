import Testing
@testable import WelloKit

@Suite("PhysiologicalState")
struct PhysiologicalStateTests {
    @Test("Bonus EFSA par état")
    func bonus() {
        #expect(PhysiologicalState.aucun.bonusML == 0)
        #expect(PhysiologicalState.grossesse.bonusML == 300)
        #expect(PhysiologicalState.allaitement.bonusML == 700)
    }

    @Test("Libellés français")
    func labels() {
        #expect(PhysiologicalState.aucun.label == "Aucun")
        #expect(PhysiologicalState.grossesse.label == "Enceinte")
        #expect(PhysiologicalState.allaitement.label == "Allaitante")
    }

    @Test("Initialisable depuis son rawValue (persistance profil)")
    func rawValue() {
        #expect(PhysiologicalState(rawValue: "grossesse") == .grossesse)
    }
}
