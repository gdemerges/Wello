import Testing
@testable import WelloKit

@Suite("HydrationCalculator")
struct HydrationCalculatorTests {

    let calc = HydrationCalculator()

    @Test("Cas nominal : base = poids × 35, sans bonus")
    func casDeBase() {
        // 70 kg → 2450 ml de base ; aucun effort, pas de météo, plancher 2000.
        let inputs = CalculatorInputs(weightKg: 70, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)

        #expect(r.baseML == 2450)
        #expect(r.activityBonusML == 0)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2450)
        #expect(r.plancherContraignant == false)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Activité : 1 ml par kcal d'énergie active")
    func activitéProportionnelle() {
        // 300 kcal brûlées → 300 ml.
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 300, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.baseML == 2800)
        #expect(r.activityBonusML == 300)
        #expect(r.totalML == 3100)
    }

    @Test("Énergie active arrondie au ml près")
    func activitéArrondie() {
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 250.6, weather: nil, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).activityBonusML == 251)
    }

    @Test("Activité plafonnée à 1000 ml")
    func activitéPlafonnée() {
        // 1200 kcal → 1200 ml théoriques, bridé à 1000.
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 1200, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.activityBonusML == 1000)
        #expect(r.totalML == 3800)           // 2800 + 1000
    }

    @Test("Météo absente (nil) → bonus 0, calcul OK")
    func météoAbsente() {
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2800)
    }

    @Test("Température > 28°C → +300")
    func bonusTempSeule() {
        let w = WeatherSnapshot(temperatureC: 30, humidityPct: 50)
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 300)
    }

    @Test("Humidité > 70% → +200")
    func bonusHumiditéSeule() {
        let w = WeatherSnapshot(temperatureC: 20, humidityPct: 80)
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 200)
    }

    @Test("Chaud ET humide → +500")
    func bonusMétéoCombiné() {
        let w = WeatherSnapshot(temperatureC: 30, humidityPct: 80)
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 0, weather: w, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 500)
        #expect(r.totalML == 3300)
    }

    @Test("Seuils stricts : exactement 28°C / 70% ne déclenchent pas")
    func seuilsStricts() {
        let w = WeatherSnapshot(temperatureC: 28, humidityPct: 70)
        let inputs = CalculatorInputs(weightKg: 80, activeEnergyKcal: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 0)
    }

    @Test("physiologicalML = base + activité + météo, indépendant du plancher")
    func besoinPhysiologique() {
        // 60 kg → 2100 base ; le plancher 2500 relève le total, mais le besoin
        // physiologique reste 2100 + activité + météo (le plancher n'est pas un terme additionné).
        let w = WeatherSnapshot(temperatureC: 30, humidityPct: 80)   // +500
        let inputs = CalculatorInputs(weightKg: 60, activeEnergyKcal: 330, weather: w, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.physiologicalML == 2930)   // 2100 + 330 + 500
        #expect(r.totalML == 2930)           // > plancher 2500, donc le physiologique gagne
    }

    @Test("physiologicalML reste sous le total quand le plancher contraint")
    func physiologiqueSousPlancher() {
        // 50 kg → 1750 base, rien d'autre ; plancher 2500 relève le total.
        let inputs = CalculatorInputs(weightKg: 50, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.physiologicalML == 1750)
        #expect(r.totalML == 2500)
    }

    @Test("Plancher médical relève l'objectif quand le physiologique est plus bas")
    func plancherContraignant() {
        // 60 kg → 2100 base ; plancher 2500 doit gagner.
        let inputs = CalculatorInputs(weightKg: 60, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 2500)
        #expect(r.plancherContraignant == true)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Plancher non contraignant quand le physiologique est plus haut")
    func plancherNonContraignant() {
        let inputs = CalculatorInputs(weightKg: 90, activeEnergyKcal: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 3150)          // 90 × 35
        #expect(r.plancherContraignant == false)
    }

    @Test("Objectif bridé au plafond global de 4000 ml")
    func plafondGlobal() {
        // 100 kg → 3500 ; 990 kcal → 990 ml ; chaud+humide → 500 ; total brut 4990 → bridé 4000.
        let w = WeatherSnapshot(temperatureC: 32, humidityPct: 85)
        let inputs = CalculatorInputs(weightKg: 100, activeEnergyKcal: 990, weather: w, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.activityBonusML == 990)   // sous le plafond de 1000
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }

    @Test("Plafond prime même sur un plancher médical incohérent (> 4000)")
    func plafondPrimeSurPlancher() {
        // Plancher 4500 invalide (le Profil l'empêche) : le plafond de sécurité prime.
        let inputs = CalculatorInputs(weightKg: 70, activeEnergyKcal: 0, weather: nil, medicalFloorML: 4500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }
}
