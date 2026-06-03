import Testing
@testable import WelloKit

@Suite("HydrationCalculator")
struct HydrationCalculatorTests {

    let calc = HydrationCalculator()

    @Test("Cas nominal : base = poids × 35, sans bonus")
    func casDeBase() {
        // 70 kg → 2450 ml de base ; aucun effort, pas de météo, plancher 2000.
        let inputs = CalculatorInputs(weightKg: 70, effortMinutes: 0, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)

        #expect(r.baseML == 2450)
        #expect(r.activityBonusML == 0)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2450)
        #expect(r.plancherContraignant == false)
        #expect(r.plafondAppliqué == false)
    }
}
