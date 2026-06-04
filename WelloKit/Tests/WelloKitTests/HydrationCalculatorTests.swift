import Testing
@testable import WelloKit

@Suite("HydrationCalculator")
struct HydrationCalculatorTests {

    let calc = HydrationCalculator()

    @Test("Base homme = 2000 ml (EFSA), sans bonus")
    func baseHomme() {
        let r = calc.calculate(CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil))
        #expect(r.baseML == 2000)
        #expect(r.activityBonusML == 0)
        #expect(r.weatherBonusML == 0)
        #expect(r.lifeStageBonusML == 0)
        #expect(r.renalBonusML == 0)
        #expect(r.totalML == 2000)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Base femme = 1600 ml (EFSA), sans bonus")
    func baseFemme() {
        let r = calc.calculate(CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil))
        #expect(r.baseML == 1600)
        #expect(r.totalML == 1600)
    }

    @Test("Activité : 1 ml par kcal d'énergie active")
    func activitéProportionnelle() {
        let r = calc.calculate(CalculatorInputs(sex: .homme, activeEnergyKcal: 300, weather: nil))
        #expect(r.activityBonusML == 300)
        #expect(r.totalML == 2300)
    }

    @Test("Énergie active arrondie au ml près")
    func activitéArrondie() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 250.6, weather: nil)
        #expect(calc.calculate(inputs).activityBonusML == 251)
    }

    @Test("Activité plafonnée à 1000 ml")
    func activitéPlafonnée() {
        let r = calc.calculate(CalculatorInputs(sex: .homme, activeEnergyKcal: 1200, weather: nil))
        #expect(r.activityBonusML == 1000)
        #expect(r.totalML == 3000)
    }

    @Test("Météo absente (nil) → bonus 0")
    func météoAbsente() {
        let r = calc.calculate(CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil))
        #expect(r.weatherBonusML == 0)
    }

    @Test("Ressenti ≤ 27°C → bonus météo 0")
    func ressentiSousConfort() {
        for ressentie in [20.0, 27.0] {
            let w = WeatherSnapshot(apparentTemperatureC: ressentie)
            let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w)
            #expect(calc.calculate(inputs).weatherBonusML == 0)
        }
    }

    @Test("Au-dessus du confort : 50 ml par °C ressenti")
    func ressentiLinéaire() {
        let w = WeatherSnapshot(apparentTemperatureC: 33)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w)
        #expect(calc.calculate(inputs).weatherBonusML == 300)
    }

    @Test("Bonus météo plafonné à 600 ml")
    func ressentiPlafonné() {
        let w = WeatherSnapshot(apparentTemperatureC: 45)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w)
        #expect(calc.calculate(inputs).weatherBonusML == 600)
    }

    @Test("Grossesse ajoute +300 ml")
    func grossesse() {
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil,
                                      physiologicalState: .grossesse)
        let r = calc.calculate(inputs)
        #expect(r.lifeStageBonusML == 300)
        #expect(r.totalML == 1900)
    }

    @Test("Allaitement ajoute +700 ml")
    func allaitement() {
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil,
                                      physiologicalState: .allaitement)
        let r = calc.calculate(inputs)
        #expect(r.lifeStageBonusML == 700)
        #expect(r.totalML == 2300)
    }

    @Test("État physiologique aucun → +0 ml")
    func étatAucun() {
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil,
                                      physiologicalState: .aucun)
        #expect(calc.calculate(inputs).lifeStageBonusML == 0)
    }

    @Test("Besoin rénal additif (lithiase)")
    func besoinRénal() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil,
                                      renalBonusML: 1000)
        let r = calc.calculate(inputs)
        #expect(r.renalBonusML == 1000)
        #expect(r.totalML == 3000)
    }

    @Test("Cumul état physiologique + rénal + activité + météo")
    func cumul() {
        let w = WeatherSnapshot(apparentTemperatureC: 33)   // +300 météo
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 200, weather: w,
                                      physiologicalState: .allaitement, renalBonusML: 800)
        let r = calc.calculate(inputs)
        // 1600 + 200 + 300 + 700 + 800 = 3600
        #expect(r.physiologicalML == 3600)
        #expect(r.totalML == 3600)
        #expect(r.plafondAppliqué == false)
    }

    @Test("physiologicalML = somme de tous les termes")
    func besoinPhysiologique() {
        let w = WeatherSnapshot(apparentTemperatureC: 37)   // +500 météo
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 330, weather: w)
        let r = calc.calculate(inputs)
        // 2000 + 330 + 500 = 2830
        #expect(r.physiologicalML == 2830)
        #expect(r.totalML == 2830)
    }

    @Test("Total bridé au plafond de sécurité 4000 ml")
    func plafond() {
        let w = WeatherSnapshot(apparentTemperatureC: 50)   // +600 météo
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 2000, weather: w,
                                      physiologicalState: .allaitement, renalBonusML: 1500)
        // 2000 + 1000 + 600 + 700 + 1500 = 5800 → bridé
        let r = calc.calculate(inputs)
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }

    @Test("Besoin rénal négatif ignoré (clampé à 0)")
    func rénalNégatifClampé() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil,
                                      renalBonusML: -500)
        let r = calc.calculate(inputs)
        #expect(r.renalBonusML == 0)
        #expect(r.totalML == 2000)
    }
}
