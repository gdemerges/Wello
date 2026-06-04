import Testing
@testable import WelloKit

@Suite("HydrationCalculator")
struct HydrationCalculatorTests {

    let calc = HydrationCalculator()

    @Test("Base homme = 2000 ml (EFSA), sans bonus")
    func baseHomme() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.baseML == 2000)
        #expect(r.activityBonusML == 0)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2000)
        #expect(r.plancherContraignant == false)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Base femme = 1600 ml (EFSA), sans bonus")
    func baseFemme() {
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.baseML == 1600)
        #expect(r.totalML == 1600)
    }

    @Test("Activité : 1 ml par kcal d'énergie active")
    func activitéProportionnelle() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 300, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.baseML == 2000)
        #expect(r.activityBonusML == 300)
        #expect(r.totalML == 2300)
    }

    @Test("Énergie active arrondie au ml près")
    func activitéArrondie() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 250.6, weather: nil, medicalFloorML: 1500)
        #expect(calc.calculate(inputs).activityBonusML == 251)
    }

    @Test("Activité plafonnée à 1000 ml")
    func activitéPlafonnée() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 1200, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.activityBonusML == 1000)
        #expect(r.totalML == 3000)
    }

    @Test("Météo absente (nil) → bonus 0, calcul OK")
    func météoAbsente() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2000)
    }

    @Test("Température ressentie au seuil de confort ou en dessous (≤ 27°C) → bonus 0")
    func ressentiSousConfort() {
        for ressentie in [20.0, 27.0] {
            let w = WeatherSnapshot(apparentTemperatureC: ressentie)
            let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w, medicalFloorML: 1500)
            #expect(calc.calculate(inputs).weatherBonusML == 0)
        }
    }

    @Test("Au-dessus du confort : 50 ml par °C ressenti")
    func ressentiLinéaire() {
        let w = WeatherSnapshot(apparentTemperatureC: 33)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 300)
        #expect(r.totalML == 2300)
    }

    @Test("Bonus météo plafonné à 600 ml")
    func ressentiPlafonné() {
        let w = WeatherSnapshot(apparentTemperatureC: 45)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: w, medicalFloorML: 1500)
        #expect(calc.calculate(inputs).weatherBonusML == 600)
    }

    @Test("physiologicalML = base + activité + météo, indépendant du plancher")
    func besoinPhysiologique() {
        let w = WeatherSnapshot(apparentTemperatureC: 37)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 330, weather: w, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.physiologicalML == 2830)
        #expect(r.totalML == 2830)
    }

    @Test("physiologicalML reste sous le total quand le plancher contraint")
    func physiologiqueSousPlancher() {
        let inputs = CalculatorInputs(sex: .femme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.physiologicalML == 1600)
        #expect(r.totalML == 2500)
    }

    @Test("Plancher médical relève l'objectif quand le physiologique est plus bas")
    func plancherContraignant() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 2500)
        #expect(r.plancherContraignant == true)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Plancher non contraignant quand le physiologique est plus haut")
    func plancherNonContraignant() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 2000)
        #expect(r.plancherContraignant == false)
    }

    @Test("Besoin physiologique maximal (3600) reste sous le plafond de 4000")
    func physiologiqueMaxSousPlafond() {
        let w = WeatherSnapshot(apparentTemperatureC: 50)
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 2000, weather: w, medicalFloorML: 1500)
        let r = calc.calculate(inputs)
        #expect(r.activityBonusML == 1000)
        #expect(r.weatherBonusML == 600)
        #expect(r.totalML == 3600)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Plafond prime sur un plancher médical incohérent (> 4000)")
    func plafondPrimeSurPlancher() {
        let inputs = CalculatorInputs(sex: .homme, activeEnergyKcal: 0, weather: nil, medicalFloorML: 4500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }
}
