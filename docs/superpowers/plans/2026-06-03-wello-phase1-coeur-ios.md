# Wello — Phase 1 (cœur iOS) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Livrer le cœur iOS de Wello — `HydrationCalculator` pur et testé (CLI), modèles SwiftData, services HealthKit/météo/localisation/notifications derrière protocoles, `HydrationStore` `@Observable`, et 3 écrans SwiftUI (Principal, Profil, Historique).

**Architecture:** Pattern « MV » SwiftUI (pas de ViewModels) ; vues + `@Query` SwiftData ; services `@Observable` injectés via `.environment()` ; logique critique isolée dans un Swift Package `WelloKit` pur (`Sendable`, sans framework Apple), réellement compilable/testable en CLI. Le reste se compile dans Xcode.

**Tech Stack:** Swift 6.3, SwiftUI (iOS 17+), SwiftData, HealthKit, CoreLocation, UNUserNotificationCenter, Open-Meteo (sans clé). Tests : `swift test` sur WelloKit.

---

## Structure des fichiers

```
Wello/
├─ WelloKit/                                  ← Swift Package (CLI : swift build / swift test)
│  ├─ Package.swift
│  ├─ Sources/WelloKit/
│  │  ├─ Models/
│  │  │  ├─ WeatherSnapshot.swift             (struct météo Sendable)
│  │  │  ├─ CalculatorInputs.swift            (entrées du calcul)
│  │  │  └─ GoalBreakdown.swift               (résultat détaillé du calcul)
│  │  ├─ HydrationCalculator.swift            (struct pure + constantes)
│  │  └─ WeightResolver.swift                 (fallback poids HealthKit→profil, pur)
│  └─ Tests/WelloKitTests/
│     ├─ HydrationCalculatorTests.swift
│     └─ WeightResolverTests.swift
├─ Wello/                                     ← sources app (target iOS, ajoutées dans Xcode)
│  ├─ App/
│  │  └─ WelloApp.swift                       (entrée, ModelContainer, injection env, bootstrap profil)
│  ├─ Models/
│  │  ├─ UserProfile.swift                    (@Model)
│  │  ├─ DailyGoal.swift                      (@Model)
│  │  └─ HydrationLog.swift                   (@Model)
│  ├─ Services/
│  │  ├─ ServiceProtocols.swift               (protocoles + types partagés)
│  │  ├─ Mocks.swift                          (mocks pour previews)
│  │  ├─ HealthKitService.swift
│  │  ├─ WeatherService.swift                 (Open-Meteo)
│  │  ├─ LocationService.swift                (CoreLocation one-shot)
│  │  ├─ NotificationService.swift
│  │  └─ HydrationStore.swift                 (@Observable orchestration)
│  └─ Views/
│     ├─ MainView.swift                       (jauge + log rapide + breakdown)
│     ├─ GaugeView.swift                      (composant jauge circulaire)
│     ├─ BreakdownCard.swift                  (composant détail objectif)
│     ├─ ProfileView.swift
│     └─ HistoryView.swift
└─ README.md
```

**Responsabilités :** chaque fichier a une seule responsabilité. Les composants UI (`GaugeView`, `BreakdownCard`) sont séparés de `MainView` pour rester réutilisables en Phase 2 (Widget/Watch). Les services sont chacun derrière un protocole défini dans `ServiceProtocols.swift`.

**Note de vérification :** seules les tâches WelloKit (1–8) sont testables en CLI (`swift test`). Les tâches app (9–21) se vérifient par compilation dans Xcode (Cmd+B) — c'est conforme au brief (tests unitaires demandés uniquement sur le calculateur).

---

## Task 1 : Squelette du package WelloKit

**Files:**
- Create: `WelloKit/Package.swift`
- Create: `WelloKit/Sources/WelloKit/WelloKit.swift` (placeholder temporaire)

- [ ] **Step 1: Créer `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WelloKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WelloKit", targets: ["WelloKit"]),
    ],
    targets: [
        .target(name: "WelloKit"),
        .testTarget(name: "WelloKitTests", dependencies: ["WelloKit"]),
    ]
)
```

- [ ] **Step 2: Créer un placeholder pour que le package compile**

`WelloKit/Sources/WelloKit/WelloKit.swift` :

```swift
// WelloKit — logique métier pure de Wello (sans dépendance Apple framework).
```

- [ ] **Step 3: Vérifier que le package compile**

Run: `cd WelloKit && swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add WelloKit/Package.swift WelloKit/Sources/WelloKit/WelloKit.swift
git commit -m "feat(kit): squelette du package WelloKit"
```

---

## Task 2 : Types d'entrée/sortie du calculateur

**Files:**
- Create: `WelloKit/Sources/WelloKit/Models/WeatherSnapshot.swift`
- Create: `WelloKit/Sources/WelloKit/Models/CalculatorInputs.swift`
- Create: `WelloKit/Sources/WelloKit/Models/GoalBreakdown.swift`

- [ ] **Step 1: Créer `WeatherSnapshot.swift`**

```swift
import Foundation

/// Instantané météo du jour utilisé pour le bonus d'hydratation.
public struct WeatherSnapshot: Sendable, Equatable {
    /// Température moyenne du jour, en °C.
    public let temperatureC: Double
    /// Humidité relative moyenne du jour, en %.
    public let humidityPct: Double

    public init(temperatureC: Double, humidityPct: Double) {
        self.temperatureC = temperatureC
        self.humidityPct = humidityPct
    }
}
```

- [ ] **Step 2: Créer `CalculatorInputs.swift`**

```swift
import Foundation

/// Entrées du calcul d'objectif d'hydratation. `weather` est optionnel :
/// si la météo est indisponible (réseau/API down), le bonus météo vaut 0.
public struct CalculatorInputs: Sendable, Equatable {
    public let weightKg: Double
    public let effortMinutes: Int
    public let weather: WeatherSnapshot?
    public let medicalFloorML: Int

    public init(weightKg: Double, effortMinutes: Int, weather: WeatherSnapshot?, medicalFloorML: Int) {
        self.weightKg = weightKg
        self.effortMinutes = effortMinutes
        self.weather = weather
        self.medicalFloorML = medicalFloorML
    }
}
```

- [ ] **Step 3: Créer `GoalBreakdown.swift`**

```swift
import Foundation

/// Résultat détaillé du calcul, pour affichage du breakdown dans l'UI.
public struct GoalBreakdown: Sendable, Equatable {
    public let baseML: Int
    public let activityBonusML: Int
    public let weatherBonusML: Int
    public let medicalFloorML: Int
    public let totalML: Int
    /// Vrai si le plancher médical a relevé l'objectif au-dessus du besoin physiologique.
    public let plancherContraignant: Bool
    /// Vrai si l'objectif a été bridé au plafond de sécurité (anti-hyperhydratation).
    public let plafondAppliqué: Bool

    public init(baseML: Int, activityBonusML: Int, weatherBonusML: Int, medicalFloorML: Int,
                totalML: Int, plancherContraignant: Bool, plafondAppliqué: Bool) {
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.medicalFloorML = medicalFloorML
        self.totalML = totalML
        self.plancherContraignant = plancherContraignant
        self.plafondAppliqué = plafondAppliqué
    }
}
```

- [ ] **Step 4: Vérifier la compilation**

Run: `cd WelloKit && swift build`
Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add WelloKit/Sources/WelloKit/Models/
git commit -m "feat(kit): types d'entrée/sortie du calculateur"
```

---

## Task 3 : HydrationCalculator — cas de base (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift`
- Create: `WelloKit/Sources/WelloKit/HydrationCalculator.swift`

- [ ] **Step 1: Écrire le test qui échoue**

`WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` :

```swift
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
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `cd WelloKit && swift test`
Expected: FAIL — `cannot find 'HydrationCalculator' in scope`

- [ ] **Step 3: Implémenter le calculateur minimal**

`WelloKit/Sources/WelloKit/HydrationCalculator.swift` :

```swift
import Foundation

/// Calcul pur de l'objectif d'hydratation quotidien.
/// Aucune dépendance Apple framework : entièrement testable hors Xcode.
public struct HydrationCalculator: Sendable {

    /// Constantes médicales/algorithmiques nommées (cf. spec).
    public enum Constantes {
        public static let mlParKg = 35.0
        public static let mlParMinEffort = 11
        public static let plafondActivité = 1000
        public static let seuilTempC = 28.0
        public static let bonusTemp = 300
        public static let seuilHumiditéPct = 70.0
        public static let bonusHumidité = 200
        /// Plafond de sécurité global : on n'affiche jamais d'objectif supérieur.
        public static let plafondGlobal = 4000
    }

    public init() {}

    public func calculate(_ inputs: CalculatorInputs) -> GoalBreakdown {
        let base = Int((inputs.weightKg * Constantes.mlParKg).rounded())

        let activité = min(inputs.effortMinutes * Constantes.mlParMinEffort, Constantes.plafondActivité)

        let météo = bonusMétéo(inputs.weather)

        let physiologique = base + activité + météo
        // Le plancher médical ne doit jamais être sous-estimé.
        let avantPlafond = max(inputs.medicalFloorML, physiologique)
        // Plafond de sécurité anti-hyperhydratation.
        let total = min(Constantes.plafondGlobal, avantPlafond)

        return GoalBreakdown(
            baseML: base,
            activityBonusML: activité,
            weatherBonusML: météo,
            medicalFloorML: inputs.medicalFloorML,
            totalML: total,
            plancherContraignant: inputs.medicalFloorML > physiologique,
            plafondAppliqué: avantPlafond > Constantes.plafondGlobal
        )
    }

    private func bonusMétéo(_ weather: WeatherSnapshot?) -> Int {
        guard let w = weather else { return 0 }   // météo absente → bonus 0
        var bonus = 0
        if w.temperatureC > Constantes.seuilTempC { bonus += Constantes.bonusTemp }
        if w.humidityPct > Constantes.seuilHumiditéPct { bonus += Constantes.bonusHumidité }
        return bonus
    }
}
```

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `cd WelloKit && swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add WelloKit/Sources/WelloKit/HydrationCalculator.swift WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift
git commit -m "feat(kit): HydrationCalculator cas de base (TDD)"
```

---

## Task 4 : Activité plafonnée (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` (ajout)

- [ ] **Step 1: Ajouter les tests d'activité**

Ajouter dans le `struct HydrationCalculatorTests` :

```swift
    @Test("Activité : 11 ml par minute d'effort")
    func activitéProportionnelle() {
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 30, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.baseML == 2800)
        #expect(r.activityBonusML == 330)   // 30 × 11
        #expect(r.totalML == 3130)
    }

    @Test("Activité plafonnée à 1000 ml")
    func activitéPlafonnée() {
        // 120 min × 11 = 1320 → bridé à 1000.
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 120, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.activityBonusML == 1000)
        #expect(r.totalML == 3800)           // 2800 + 1000
    }
```

- [ ] **Step 2: Lancer les tests**

Run: `cd WelloKit && swift test`
Expected: PASS (l'implémentation de la Task 3 couvre déjà ce comportement)

- [ ] **Step 3: Commit**

```bash
git add WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift
git commit -m "test(kit): activité proportionnelle et plafonnée"
```

---

## Task 5 : Bonus météo et météo absente (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` (ajout)

- [ ] **Step 1: Ajouter les tests météo**

Ajouter dans le `struct HydrationCalculatorTests` :

```swift
    @Test("Météo absente (nil) → bonus 0, calcul OK")
    func météoAbsente() {
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 0, weather: nil, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 0)
        #expect(r.totalML == 2800)
    }

    @Test("Température > 28°C → +300")
    func bonusTempSeule() {
        let w = WeatherSnapshot(temperatureC: 30, humidityPct: 50)
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 300)
    }

    @Test("Humidité > 70% → +200")
    func bonusHumiditéSeule() {
        let w = WeatherSnapshot(temperatureC: 20, humidityPct: 80)
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 200)
    }

    @Test("Chaud ET humide → +500")
    func bonusMétéoCombiné() {
        let w = WeatherSnapshot(temperatureC: 30, humidityPct: 80)
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 0, weather: w, medicalFloorML: 2000)
        let r = calc.calculate(inputs)
        #expect(r.weatherBonusML == 500)
        #expect(r.totalML == 3300)
    }

    @Test("Seuils stricts : exactement 28°C / 70% ne déclenchent pas")
    func seuilsStricts() {
        let w = WeatherSnapshot(temperatureC: 28, humidityPct: 70)
        let inputs = CalculatorInputs(weightKg: 80, effortMinutes: 0, weather: w, medicalFloorML: 2000)
        #expect(calc.calculate(inputs).weatherBonusML == 0)
    }
```

- [ ] **Step 2: Lancer les tests**

Run: `cd WelloKit && swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift
git commit -m "test(kit): bonus météo, seuils stricts et météo absente"
```

---

## Task 6 : Plancher médical contraignant (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` (ajout)

- [ ] **Step 1: Ajouter les tests de plancher**

Ajouter dans le `struct HydrationCalculatorTests` :

```swift
    @Test("Plancher médical relève l'objectif quand le physiologique est plus bas")
    func plancherContraignant() {
        // 60 kg → 2100 base ; plancher 2500 doit gagner.
        let inputs = CalculatorInputs(weightKg: 60, effortMinutes: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 2500)
        #expect(r.plancherContraignant == true)
        #expect(r.plafondAppliqué == false)
    }

    @Test("Plancher non contraignant quand le physiologique est plus haut")
    func plancherNonContraignant() {
        let inputs = CalculatorInputs(weightKg: 90, effortMinutes: 0, weather: nil, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 3150)          // 90 × 35
        #expect(r.plancherContraignant == false)
    }
```

- [ ] **Step 2: Lancer les tests**

Run: `cd WelloKit && swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift
git commit -m "test(kit): plancher médical contraignant"
```

---

## Task 7 : Plafond global de sécurité (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` (ajout)

- [ ] **Step 1: Ajouter les tests de plafond**

Ajouter dans le `struct HydrationCalculatorTests` :

```swift
    @Test("Objectif bridé au plafond global de 4000 ml")
    func plafondGlobal() {
        // 100 kg → 3500 ; effort 90 → 990 ; chaud+humide → 500 ; total brut 4990 → bridé 4000.
        let w = WeatherSnapshot(temperatureC: 32, humidityPct: 85)
        let inputs = CalculatorInputs(weightKg: 100, effortMinutes: 90, weather: w, medicalFloorML: 2500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }

    @Test("Plafond prime même sur un plancher médical incohérent (> 4000)")
    func plafondPrimeSurPlancher() {
        // Plancher 4500 invalide (le Profil l'empêche) : le plafond de sécurité prime.
        let inputs = CalculatorInputs(weightKg: 70, effortMinutes: 0, weather: nil, medicalFloorML: 4500)
        let r = calc.calculate(inputs)
        #expect(r.totalML == 4000)
        #expect(r.plafondAppliqué == true)
    }
```

- [ ] **Step 2: Lancer les tests**

Run: `cd WelloKit && swift test`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift
git commit -m "test(kit): plafond global de sécurité"
```

---

## Task 8 : WeightResolver — fallback poids (TDD)

**Files:**
- Test: `WelloKit/Tests/WelloKitTests/WeightResolverTests.swift`
- Create: `WelloKit/Sources/WelloKit/WeightResolver.swift`

- [ ] **Step 1: Écrire le test qui échoue**

`WelloKit/Tests/WelloKitTests/WeightResolverTests.swift` :

```swift
import Testing
@testable import WelloKit

@Suite("WeightResolver")
struct WeightResolverTests {

    @Test("Utilise le poids HealthKit quand disponible")
    func utiliseHealthKit() {
        #expect(résoudrePoids(healthKitKg: 72.5, profilKg: 80) == 72.5)
    }

    @Test("Fallback sur le poids du profil quand HealthKit est absent")
    func fallbackProfil() {
        #expect(résoudrePoids(healthKitKg: nil, profilKg: 80) == 80)
    }

    @Test("Ignore un poids HealthKit non plausible (≤ 0)")
    func ignoreValeurAberrante() {
        #expect(résoudrePoids(healthKitKg: 0, profilKg: 80) == 80)
    }
}
```

- [ ] **Step 2: Lancer le test pour vérifier l'échec**

Run: `cd WelloKit && swift test --filter WeightResolver`
Expected: FAIL — `cannot find 'résoudrePoids' in scope`

- [ ] **Step 3: Implémenter le resolver**

`WelloKit/Sources/WelloKit/WeightResolver.swift` :

```swift
import Foundation

/// Choisit le poids à utiliser pour le calcul : HealthKit en priorité,
/// sinon le poids saisi dans le profil. Ignore les valeurs non plausibles.
public func résoudrePoids(healthKitKg: Double?, profilKg: Double) -> Double {
    if let hk = healthKitKg, hk > 0 { return hk }
    return profilKg
}
```

- [ ] **Step 4: Lancer le test pour vérifier le succès**

Run: `cd WelloKit && swift test`
Expected: PASS (toute la suite)

- [ ] **Step 5: Supprimer le placeholder et commit**

```bash
rm WelloKit/Sources/WelloKit/WelloKit.swift
cd WelloKit && swift build && cd ..
git add -A WelloKit/
git commit -m "feat(kit): WeightResolver fallback poids (TDD)"
```

---

## Task 9 : Modèles SwiftData

**Files:**
- Create: `Wello/Models/UserProfile.swift`
- Create: `Wello/Models/DailyGoal.swift`
- Create: `Wello/Models/HydrationLog.swift`

- [ ] **Step 1: Créer `UserProfile.swift`**

```swift
import Foundation
import SwiftData

/// Profil unique de l'utilisateur (app mono-utilisateur).
@Model
final class UserProfile {
    var weightKg: Double
    /// Plancher médical fixe (ex. 2500 ml) — suivi de calculs rénaux calciques.
    var medicalFloorML: Int
    var remindersEnabled: Bool
    var updatedAt: Date

    init(weightKg: Double = 75, medicalFloorML: Int = 2500,
         remindersEnabled: Bool = true, updatedAt: Date = .now) {
        self.weightKg = weightKg
        self.medicalFloorML = medicalFloorML
        self.remindersEnabled = remindersEnabled
        self.updatedAt = updatedAt
    }
}
```

- [ ] **Step 2: Créer `DailyGoal.swift`**

```swift
import Foundation
import SwiftData

/// Objectif calculé pour un jour donné (un seul par date, normalisée à minuit).
@Model
final class DailyGoal {
    /// Date du jour, normalisée au début de journée (`startOfDay`).
    @Attribute(.unique) var date: Date
    var baseML: Int
    var activityBonusML: Int
    var weatherBonusML: Int
    var medicalFloorML: Int
    var totalML: Int
    var calculatedAt: Date

    init(date: Date, baseML: Int, activityBonusML: Int, weatherBonusML: Int,
         medicalFloorML: Int, totalML: Int, calculatedAt: Date = .now) {
        self.date = date
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.medicalFloorML = medicalFloorML
        self.totalML = totalML
        self.calculatedAt = calculatedAt
    }
}
```

- [ ] **Step 3: Créer `HydrationLog.swift`**

```swift
import Foundation
import SwiftData

/// Une prise d'eau enregistrée.
@Model
final class HydrationLog {
    var amountML: Int
    var loggedAt: Date
    /// Provenance : "app" (saisie dans Wello) ou "healthkit" (importée).
    var source: String

    init(amountML: Int, loggedAt: Date = .now, source: String = "app") {
        self.amountML = amountML
        self.loggedAt = loggedAt
        self.source = source
    }
}
```

- [ ] **Step 4: Vérifier la compilation dans Xcode**

Ajouter les 3 fichiers au target `Wello`, puis Cmd+B.
Expected: Build succeeded.

- [ ] **Step 5: Commit**

```bash
git add Wello/Models/
git commit -m "feat(app): modèles SwiftData UserProfile, DailyGoal, HydrationLog"
```

---

## Task 10 : Protocoles de services + types partagés

**Files:**
- Create: `Wello/Services/ServiceProtocols.swift`

- [ ] **Step 1: Créer `ServiceProtocols.swift`**

```swift
import Foundation
import WelloKit

/// Lecture/écriture HealthKit. Toutes les opérations dégradent gracieusement si refusé.
protocol HealthKitServicing: Sendable {
    /// Demande les autorisations (lecture workouts+poids, écriture eau). Sans effet si déjà décidé.
    func requestAuthorization() async
    /// Minutes d'effort cumulées des workouts du jour. 0 si indisponible/refusé.
    func minutesEffortDuJour() async -> Int
    /// Dernier poids connu en kg, ou nil si indisponible/refusé.
    func dernierPoids() async -> Double?
    /// Écrit une prise d'eau dans Santé.app. No-op si refusé.
    func écrireEau(ml: Int, date: Date) async
    /// Durée totale (minutes) des workouts terminés depuis `date`. Sert au rappel post-séance.
    func minutesEffortDepuis(_ date: Date) async -> Int
}

/// Récupération météo best-effort.
protocol WeatherServicing: Sendable {
    /// Météo du jour pour des coordonnées. nil si réseau/API indisponible.
    func météoDuJour(latitude: Double, longitude: Double) async -> WeatherSnapshot?
}

/// Localisation one-shot pour alimenter la météo.
protocol LocationServicing: Sendable {
    /// Coordonnées actuelles, ou nil si refusé/indisponible.
    func coordonnéesActuelles() async -> (latitude: Double, longitude: Double)?
}

/// Planification des rappels d'hydratation.
protocol NotificationServicing: Sendable {
    func requestAuthorization() async -> Bool
    /// (Re)planifie les rappels du jour selon l'objectif et le consommé.
    func planifierRappels(objectifML: Int, consomméML: Int) async
    /// Programme un rappel post-séance (+500 ml dans l'heure).
    func programmerRappelPostSéance() async
    /// Annule tous les rappels (toggle off / désactiver pour la journée).
    func annulerTout() async
    /// Désactive les rappels jusqu'à demain matin.
    func désactiverPourLaJournée() async
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter le fichier au target ; lier le package local `WelloKit` au projet (File ▸ Add Package Dependencies ▸ Add Local ▸ dossier `WelloKit`, puis ajouter la lib `WelloKit` au target `Wello`). Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/ServiceProtocols.swift
git commit -m "feat(app): protocoles de services + liaison WelloKit"
```

---

## Task 11 : Mocks de services (pour previews)

**Files:**
- Create: `Wello/Services/Mocks.swift`

- [ ] **Step 1: Créer `Mocks.swift`**

```swift
import Foundation
import WelloKit

/// Implémentations factices pour les SwiftUI previews et le développement hors device.
struct MockHealthKitService: HealthKitServicing {
    var effort: Int = 45
    var poids: Double? = 78
    func requestAuthorization() async {}
    func minutesEffortDuJour() async -> Int { effort }
    func dernierPoids() async -> Double? { poids }
    func écrireEau(ml: Int, date: Date) async {}
    func minutesEffortDepuis(_ date: Date) async -> Int { 0 }
}

struct MockWeatherService: WeatherServicing {
    var snapshot: WeatherSnapshot? = WeatherSnapshot(temperatureC: 30, humidityPct: 75)
    func météoDuJour(latitude: Double, longitude: Double) async -> WeatherSnapshot? { snapshot }
}

struct MockLocationService: LocationServicing {
    var coords: (latitude: Double, longitude: Double)? = (48.85, 2.35)
    func coordonnéesActuelles() async -> (latitude: Double, longitude: Double)? { coords }
}

struct MockNotificationService: NotificationServicing {
    func requestAuthorization() async -> Bool { true }
    func planifierRappels(objectifML: Int, consomméML: Int) async {}
    func programmerRappelPostSéance() async {}
    func annulerTout() async {}
    func désactiverPourLaJournée() async {}
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/Mocks.swift
git commit -m "feat(app): mocks de services pour previews"
```

---

## Task 12 : HealthKitService (impl réelle)

**Files:**
- Create: `Wello/Services/HealthKitService.swift`

- [ ] **Step 1: Créer `HealthKitService.swift`**

```swift
import Foundation
import HealthKit

/// Implémentation réelle de l'accès HealthKit. Dégrade gracieusement (retours neutres)
/// si HealthKit est indisponible ou l'autorisation refusée.
final class HealthKitService: HealthKitServicing {
    private let store = HKHealthStore()

    private let workoutType = HKObjectType.workoutType()
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let waterType = HKQuantityType(.dietaryWater)

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let read: Set<HKObjectType> = [workoutType, bodyMassType]
        let write: Set<HKSampleType> = [waterType]
        try? await store.requestAuthorization(toShare: write, read: read)
    }

    func minutesEffortDuJour() async -> Int {
        let début = Calendar.current.startOfDay(for: .now)
        return await minutesEffortDepuis(début)
    }

    func minutesEffortDepuis(_ date: Date) async -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let prédicat = HKQuery.predicateForSamples(withStart: date, end: .now)
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: workoutType, predicate: prédicat,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        let secondes = workouts.reduce(0) { $0 + $1.duration }
        return Int(secondes / 60)
    }

    func dernierPoids() async -> Double? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let tri = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let sample: HKQuantitySample? = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: bodyMassType, predicate: nil,
                                  limit: 1, sortDescriptors: [tri]) { _, samples, _ in
                cont.resume(returning: samples?.first as? HKQuantitySample)
            }
            store.execute(q)
        }
        return sample?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    func écrireEau(ml: Int, date: Date) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let quantité = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml))
        let sample = HKQuantitySample(type: waterType, quantity: quantité, start: date, end: date)
        try? await store.save(sample)
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Activer la capability **HealthKit** sur le target (Signing & Capabilities ▸ + HealthKit). Ajouter le fichier ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/HealthKitService.swift
git commit -m "feat(app): HealthKitService (lecture effort/poids, écriture eau)"
```

---

## Task 13 : WeatherService (Open-Meteo)

**Files:**
- Create: `Wello/Services/WeatherService.swift`

- [ ] **Step 1: Créer `WeatherService.swift`**

```swift
import Foundation
import WelloKit

/// Récupère la météo du jour via Open-Meteo (gratuit, sans clé). Best-effort : nil sur échec.
struct WeatherService: WeatherServicing {

    func météoDuJour(latitude: Double, longitude: Double) async -> WeatherSnapshot? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(latitude)),
            .init(name: "longitude", value: String(longitude)),
            .init(name: "daily", value: "temperature_2m_max"),
            .init(name: "hourly", value: "relative_humidity_2m"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "auto"),
        ]
        guard let url = comps.url else { return nil }

        do {
            let (data, réponse) = try await URLSession.shared.data(from: url)
            guard (réponse as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let dto = try JSONDecoder().decode(OpenMeteoDTO.self, from: data)
            guard let tempMax = dto.daily.temperature_2m_max.first else { return nil }
            let humidités = dto.hourly.relative_humidity_2m
            let humiditéMoy = humidités.isEmpty ? 0 : humidités.reduce(0, +) / Double(humidités.count)
            return WeatherSnapshot(temperatureC: tempMax, humidityPct: humiditéMoy)
        } catch {
            return nil   // réseau/API down → météo absente, le calcul tourne quand même
        }
    }
}

/// DTO interne de décodage Open-Meteo.
private struct OpenMeteoDTO: Decodable {
    struct Daily: Decodable { let temperature_2m_max: [Double] }
    struct Hourly: Decodable { let relative_humidity_2m: [Double] }
    let daily: Daily
    let hourly: Hourly
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/WeatherService.swift
git commit -m "feat(app): WeatherService Open-Meteo (best-effort)"
```

---

## Task 14 : LocationService (CoreLocation one-shot)

**Files:**
- Create: `Wello/Services/LocationService.swift`

- [ ] **Step 1: Créer `LocationService.swift`**

```swift
import Foundation
import CoreLocation

/// Fournit les coordonnées actuelles en one-shot pour alimenter la météo. Best-effort.
final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<(latitude: Double, longitude: Double)?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func coordonnéesActuelles() async -> (latitude: Double, longitude: Double)? {
        let statut = manager.authorizationStatus
        guard statut != .denied, statut != .restricted else { return nil }
        if statut == .notDetermined { manager.requestWhenInUseAuthorization() }
        return await withCheckedContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coord = locations.first?.coordinate
        let result = coord.map { (latitude: $0.latitude, longitude: $0.longitude) }
        continuation?.resume(returning: result)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(returning: nil)
        continuation = nil
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; ajouter la clé Info.plist `NSLocationWhenInUseUsageDescription`. Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/LocationService.swift
git commit -m "feat(app): LocationService one-shot (CoreLocation)"
```

---

## Task 15 : NotificationService

**Files:**
- Create: `Wello/Services/NotificationService.swift`

- [ ] **Step 1: Créer `NotificationService.swift`**

```swift
import Foundation
import UserNotifications

/// Planifie les rappels d'hydratation : fenêtre 7h–21h, jamais deux rapprochés,
/// rappel post-séance, et rappels de retard à 14h et 17h. Action directe « logger 250 ml ».
final class NotificationService: NotificationServicing {

    static let actionLog250 = "WELLO_LOG_250"
    static let catégorieRappel = "WELLO_RAPPEL"

    private let center = UNUserNotificationCenter.current()

    init() {
        let action = UNNotificationAction(identifier: Self.actionLog250,
                                          title: "Logger 250 ml", options: [])
        let catégorie = UNNotificationCategory(identifier: Self.catégorieRappel,
                                               actions: [action], intentIdentifiers: [])
        center.setNotificationCategories([catégorie])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func planifierRappels(objectifML: Int, consomméML: Int) async {
        // On repart d'une ardoise propre pour les rappels récurrents du jour.
        center.removePendingNotificationRequests(withIdentifiers: ["wello.14h", "wello.17h"])

        // Rappel de retard à 14h et 17h, uniquement si en dessous du rythme attendu.
        await programmerSiRetard(heure: 14, objectifML: objectifML, ratioAttendu: 0.5, id: "wello.14h")
        await programmerSiRetard(heure: 17, objectifML: objectifML, ratioAttendu: 0.75, id: "wello.17h")
    }

    private func programmerSiRetard(heure: Int, objectifML: Int, ratioAttendu: Double, id: String) async {
        // La fenêtre autorisée est 7h–21h ; 14h et 17h y sont inclus.
        let contenu = UNMutableNotificationContent()
        contenu.title = "Hydratation"
        contenu.body = "Pense à boire pour rester sur ton objectif du jour."
        contenu.categoryIdentifier = Self.catégorieRappel
        contenu.sound = .default

        var comps = DateComponents()
        comps.hour = heure
        comps.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: contenu, trigger: trigger)
        try? await center.add(req)
    }

    func programmerRappelPostSéance() async {
        let contenu = UNMutableNotificationContent()
        contenu.title = "Bien joué pour ta séance 💪"
        contenu.body = "Bois ~500 ml dans l'heure pour récupérer."
        contenu.categoryIdentifier = Self.catégorieRappel
        contenu.sound = .default

        // Dans 5 min ; on évite de superposer aux rappels horaires (jamais deux rapprochés).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        let req = UNNotificationRequest(identifier: "wello.postseance", content: contenu, trigger: trigger)
        try? await center.add(req)
    }

    func annulerTout() async {
        center.removeAllPendingNotificationRequests()
    }

    func désactiverPourLaJournée() async {
        // Annule tout ; les rappels seront reprogrammés au prochain refresh de demain.
        center.removeAllPendingNotificationRequests()
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/NotificationService.swift
git commit -m "feat(app): NotificationService (rappels fenêtre 7h-21h, post-séance, retard)"
```

---

## Task 16 : HydrationStore (orchestration `@Observable`)

**Files:**
- Create: `Wello/Services/HydrationStore.swift`

- [ ] **Step 1: Créer `HydrationStore.swift`**

```swift
import Foundation
import SwiftData
import WelloKit

/// Orchestrateur central : calcule/rafraîchit l'objectif du jour et enregistre les prises d'eau.
/// Injecté dans l'environnement SwiftUI. Source de vérité du « consommé » = somme des HydrationLog.
@MainActor
@Observable
final class HydrationStore {
    private let modelContext: ModelContext
    private let healthKit: HealthKitServicing
    private let weather: WeatherServicing
    private let location: LocationServicing
    private let notifications: NotificationServicing
    private let calculator = HydrationCalculator()

    /// Objectif détaillé du jour, recalculé par `refreshToday()`.
    private(set) var breakdown: GoalBreakdown?

    init(modelContext: ModelContext,
         healthKit: HealthKitServicing,
         weather: WeatherServicing,
         location: LocationServicing,
         notifications: NotificationServicing) {
        self.modelContext = modelContext
        self.healthKit = healthKit
        self.weather = weather
        self.location = location
        self.notifications = notifications
    }

    /// Récupère ou crée l'unique profil utilisateur.
    func profilCourant() -> UserProfile {
        let descripteur = FetchDescriptor<UserProfile>()
        if let existant = try? modelContext.fetch(descripteur).first {
            return existant
        }
        let nouveau = UserProfile()
        modelContext.insert(nouveau)
        return nouveau
    }

    /// Recalcule l'objectif du jour à partir du poids, de l'effort et de la météo (best-effort),
    /// puis met à jour (upsert) le DailyGoal du jour. Replanifie les rappels.
    func refreshToday() async {
        let profil = profilCourant()

        await healthKit.requestAuthorization()
        let effort = await healthKit.minutesEffortDuJour()
        let poidsHK = await healthKit.dernierPoids()
        let poids = résoudrePoids(healthKitKg: poidsHK, profilKg: profil.weightKg)

        var snapshot: WeatherSnapshot? = nil
        if let coords = await location.coordonnéesActuelles() {
            snapshot = await weather.météoDuJour(latitude: coords.latitude, longitude: coords.longitude)
        }

        let inputs = CalculatorInputs(weightKg: poids, effortMinutes: effort,
                                      weather: snapshot, medicalFloorML: profil.medicalFloorML)
        let resultat = calculator.calculate(inputs)
        breakdown = resultat
        upsertDailyGoal(resultat)

        if profil.remindersEnabled {
            await notifications.planifierRappels(objectifML: resultat.totalML, consomméML: consomméAujourdhui())
        }
    }

    /// Enregistre une prise d'eau : SwiftData (source de vérité) + écriture HealthKit (Santé.app).
    func log(ml: Int) async {
        let entrée = HydrationLog(amountML: ml, loggedAt: .now, source: "app")
        modelContext.insert(entrée)
        await healthKit.écrireEau(ml: ml, date: .now)

        if let objectif = breakdown?.totalML {
            await notifications.planifierRappels(objectifML: objectif, consomméML: consomméAujourdhui())
        }
    }

    /// Somme des prises d'eau du jour (toutes sources).
    func consomméAujourdhui() -> Int {
        let début = Calendar.current.startOfDay(for: .now)
        let descripteur = FetchDescriptor<HydrationLog>(
            predicate: #Predicate { $0.loggedAt >= début }
        )
        let logs = (try? modelContext.fetch(descripteur)) ?? []
        return logs.reduce(0) { $0 + $1.amountML }
    }

    private func upsertDailyGoal(_ r: GoalBreakdown) {
        let jour = Calendar.current.startOfDay(for: .now)
        let descripteur = FetchDescriptor<DailyGoal>(predicate: #Predicate { $0.date == jour })
        let existant = try? modelContext.fetch(descripteur).first

        if let goal = existant ?? nil {
            goal.baseML = r.baseML
            goal.activityBonusML = r.activityBonusML
            goal.weatherBonusML = r.weatherBonusML
            goal.medicalFloorML = r.medicalFloorML
            goal.totalML = r.totalML
            goal.calculatedAt = .now
        } else {
            let goal = DailyGoal(date: jour, baseML: r.baseML, activityBonusML: r.activityBonusML,
                                 weatherBonusML: r.weatherBonusML, medicalFloorML: r.medicalFloorML,
                                 totalML: r.totalML)
            modelContext.insert(goal)
        }
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Services/HydrationStore.swift
git commit -m "feat(app): HydrationStore orchestration (refresh objectif, log, consommé)"
```

---

## Task 17 : Composant GaugeView

**Files:**
- Create: `Wello/Views/GaugeView.swift`

- [ ] **Step 1: Créer `GaugeView.swift`**

```swift
import SwiftUI

/// Jauge circulaire de progression réutilisable (iOS, et plus tard Widget/Watch).
struct GaugeView: View {
    let consomméML: Int
    let objectifML: Int

    private var progression: Double {
        guard objectifML > 0 else { return 0 }
        return min(Double(consomméML) / Double(objectifML), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 18)
            Circle()
                .trim(from: 0, to: progression)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progression)
            VStack(spacing: 4) {
                Text("\(consomméML)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("/ \(objectifML) ml")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
        .padding()
    }
}

#Preview {
    GaugeView(consomméML: 1200, objectifML: 2500)
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B (et previewer si souhaité).
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Views/GaugeView.swift
git commit -m "feat(app): composant GaugeView (jauge circulaire)"
```

---

## Task 18 : Composant BreakdownCard

**Files:**
- Create: `Wello/Views/BreakdownCard.swift`

- [ ] **Step 1: Créer `BreakdownCard.swift`**

```swift
import SwiftUI
import WelloKit

/// Carte détaillant la composition de l'objectif du jour.
struct BreakdownCard: View {
    let breakdown: GoalBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Détail de l'objectif")
                .font(.headline)
            ligne("Base (poids)", breakdown.baseML)
            ligne("Activité", breakdown.activityBonusML)
            ligne("Météo", breakdown.weatherBonusML)
            ligne("Plancher médical", breakdown.medicalFloorML)
            Divider()
            HStack {
                Text("Total").fontWeight(.semibold)
                Spacer()
                Text("\(breakdown.totalML) ml").fontWeight(.semibold)
            }
            if breakdown.plancherContraignant {
                badge("Objectif relevé au plancher médical", systemImage: "cross.case")
            }
            if breakdown.plafondAppliqué {
                badge("Bridé au plafond de sécurité (4000 ml)", systemImage: "exclamationmark.shield")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func ligne(_ libellé: String, _ valeur: Int) -> some View {
        HStack {
            Text(libellé).foregroundStyle(.secondary)
            Spacer()
            Text("\(valeur) ml")
        }
    }

    private func badge(_ texte: String, systemImage: String) -> some View {
        Label(texte, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.orange)
            .padding(.top, 4)
    }
}

#Preview {
    BreakdownCard(breakdown: GoalBreakdown(baseML: 2450, activityBonusML: 500, weatherBonusML: 300,
                                           medicalFloorML: 2500, totalML: 3250,
                                           plancherContraignant: false, plafondAppliqué: false))
    .padding()
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Views/BreakdownCard.swift
git commit -m "feat(app): composant BreakdownCard (détail objectif)"
```

---

## Task 19 : MainView

**Files:**
- Create: `Wello/Views/MainView.swift`

- [ ] **Step 1: Créer `MainView.swift`**

```swift
import SwiftUI
import SwiftData
import WelloKit

/// Écran principal : jauge de progression, boutons de log rapide et détail de l'objectif.
struct MainView: View {
    @Environment(HydrationStore.self) private var store
    /// On observe les logs du jour pour mettre à jour la jauge automatiquement.
    @Query private var logs: [HydrationLog]

    private var consommé: Int { logs.reduce(0) { $0 + $1.amountML } }
    private var objectif: Int { store.breakdown?.totalML ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    GaugeView(consomméML: consommé, objectifML: objectif)

                    HStack(spacing: 12) {
                        boutonLog(150)
                        boutonLog(250)
                        boutonLog(500)
                    }

                    if let breakdown = store.breakdown {
                        BreakdownCard(breakdown: breakdown).padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Wello")
            .task { await store.refreshToday() }
        }
    }

    private func boutonLog(_ ml: Int) -> some View {
        Button {
            Task { await store.log(ml: ml) }
        } label: {
            Text("+\(ml)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
    }
}
```

- [ ] **Step 2: Initialiser le `@Query` sur le jour courant**

Remplacer la déclaration `@Query private var logs: [HydrationLog]` par un init filtrant le jour
(SwiftData ne permet pas `.now` dans un prédicat de propriété, on le passe via `init`) :

```swift
    init() {
        let début = Calendar.current.startOfDay(for: .now)
        _logs = Query(filter: #Predicate<HydrationLog> { $0.loggedAt >= début })
    }
```

- [ ] **Step 3: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 4: Commit**

```bash
git add Wello/Views/MainView.swift
git commit -m "feat(app): MainView (jauge, log rapide 150/250/500, breakdown)"
```

---

## Task 20 : ProfileView

**Files:**
- Create: `Wello/Views/ProfileView.swift`

- [ ] **Step 1: Créer `ProfileView.swift`**

```swift
import SwiftUI
import SwiftData

/// Édition du profil : poids, plancher médical (validé ≤ 4000), rappels.
struct ProfileView: View {
    @Environment(HydrationStore.self) private var store
    @Environment(\.modelContext) private var modelContext
    @Query private var profils: [UserProfile]

    private var profil: UserProfile? { profils.first }

    var body: some View {
        NavigationStack {
            Form {
                if let profil {
                    Section("Poids") {
                        Stepper(value: Binding(get: { profil.weightKg },
                                               set: { profil.weightKg = $0; profil.updatedAt = .now }),
                                in: 30...250, step: 0.5) {
                            Text("\(profil.weightKg, specifier: "%.1f") kg")
                        }
                    }
                    Section("Plancher médical") {
                        Stepper(value: Binding(get: { profil.medicalFloorML },
                                               set: { profil.medicalFloorML = min($0, 4000); profil.updatedAt = .now }),
                                in: 1000...4000, step: 100) {
                            Text("\(profil.medicalFloorML) ml")
                        }
                        Text("Plafonné à 4000 ml pour éviter toute hyperhydratation.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Rappels") {
                        Toggle("Rappels intelligents", isOn: Binding(
                            get: { profil.remindersEnabled },
                            set: { profil.remindersEnabled = $0; profil.updatedAt = .now }))
                    }
                }
            }
            .navigationTitle("Profil")
            .task { _ = store.profilCourant() }   // garantit l'existence d'un profil
        }
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Views/ProfileView.swift
git commit -m "feat(app): ProfileView (poids, plancher ≤ 4000, rappels)"
```

---

## Task 21 : HistoryView

**Files:**
- Create: `Wello/Views/HistoryView.swift`

- [ ] **Step 1: Créer `HistoryView.swift`**

```swift
import SwiftUI
import SwiftData

/// Historique : objectif vs consommé par jour.
struct HistoryView: View {
    @Query(sort: \DailyGoal.date, order: .reverse) private var objectifs: [DailyGoal]
    @Query private var logs: [HydrationLog]

    var body: some View {
        NavigationStack {
            List(objectifs) { goal in
                let consommé = consommé(pour: goal.date)
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.date, style: .date).font(.headline)
                    HStack {
                        Text("Objectif : \(goal.totalML) ml")
                        Spacer()
                        Text("Bu : \(consommé) ml")
                            .foregroundStyle(consommé >= goal.totalML ? .green : .secondary)
                    }
                    .font(.subheadline)
                }
            }
            .navigationTitle("Historique")
        }
    }

    private func consommé(pour jour: Date) -> Int {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.loggedAt, inSameDayAs: jour) }
                   .reduce(0) { $0 + $1.amountML }
    }
}
```

- [ ] **Step 2: Vérifier la compilation dans Xcode**

Ajouter au target ; Cmd+B.
Expected: Build succeeded.

- [ ] **Step 3: Commit**

```bash
git add Wello/Views/HistoryView.swift
git commit -m "feat(app): HistoryView (objectif vs consommé par jour)"
```

---

## Task 22 : WelloApp (entrée, ModelContainer, injection, TabView)

**Files:**
- Create: `Wello/App/WelloApp.swift`

- [ ] **Step 1: Créer `WelloApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct WelloApp: App {
    /// Conteneur SwiftData pour les 3 modèles.
    let container: ModelContainer
    @State private var store: HydrationStore

    init() {
        let container = try! ModelContainer(for: UserProfile.self, DailyGoal.self, HydrationLog.self)
        self.container = container
        // Services réels injectés dans l'orchestrateur.
        _store = State(initialValue: HydrationStore(
            modelContext: container.mainContext,
            healthKit: HealthKitService(),
            weather: WeatherService(),
            location: LocationService(),
            notifications: NotificationService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                MainView()
                    .tabItem { Label("Aujourd'hui", systemImage: "drop.fill") }
                HistoryView()
                    .tabItem { Label("Historique", systemImage: "calendar") }
                ProfileView()
                    .tabItem { Label("Profil", systemImage: "person.fill") }
            }
            .environment(store)
        }
        .modelContainer(container)
    }
}
```

- [ ] **Step 2: Vérifier la compilation et le lancement dans Xcode**

S'assurer qu'il n'existe qu'un seul `@main` (supprimer le `ContentView`/`App` généré par défaut si présent). Cmd+R sur simulateur iOS 17+.
Expected: l'app se lance, 3 onglets visibles, la jauge s'affiche, les boutons +150/+250/+500 incrémentent la jauge, le profil édite poids/plancher.

- [ ] **Step 3: Commit**

```bash
git add Wello/App/WelloApp.swift
git commit -m "feat(app): WelloApp (ModelContainer, injection services, TabView)"
```

---

## Task 23 : README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Créer `README.md`**

````markdown
# Wello — Suivi d'hydratation (iOS)

App iOS personnelle, mono-utilisateur, 100 % locale. Calcule un objectif d'hydratation
quotidien personnalisé (poids, activité HealthKit, météo Open-Meteo, plancher médical) et
aide à le suivre.

## Lancement

1. Ouvrir le projet dans Xcode 26+ (iOS 17+).
2. Lier le package local : File ▸ Add Package Dependencies ▸ Add Local ▸ dossier `WelloKit`,
   puis ajouter la bibliothèque `WelloKit` au target `Wello`.
3. Ajouter les fichiers de `Wello/` au target de l'app (Models, Services, Views, App).
4. Capabilities & Info.plist (voir ci-dessous).
5. Cmd+R sur un simulateur ou un device iOS 17+.

## Tests de la logique métier

La logique critique (`HydrationCalculator`, `WeightResolver`) vit dans le package `WelloKit`
et se teste sans Xcode :

```bash
cd WelloKit && swift test
```

## Permissions

Activer la capability **HealthKit** sur le target (Signing & Capabilities ▸ + HealthKit),
et renseigner dans Info.plist :

- `NSHealthShareUsageDescription` — lecture des séances et du poids.
- `NSHealthUpdateUsageDescription` — écriture des prises d'eau dans Santé.app.
- `NSLocationWhenInUseUsageDescription` — localisation pour la météo locale.

Les notifications sont demandées à l'usage. **Tous les refus sont gérés** : l'app reste
pleinement utilisable en saisie manuelle (effort = 0, poids depuis le profil, météo = bonus 0,
pas de rappels).

## Où ajuster le plancher médical

Onglet **Profil** ▸ section « Plancher médical » (1000–4000 ml). Valeur par défaut : 2500 ml.
Le plancher n'est jamais sous-estimé par le calcul, et l'objectif affiché est plafonné à
4000 ml (sécurité anti-hyperhydratation).

## Architecture

- `WelloKit/` — logique pure testable (calcul d'objectif, fallback poids).
- `Wello/Models` — modèles SwiftData (`UserProfile`, `DailyGoal`, `HydrationLog`).
- `Wello/Services` — HealthKit, météo, localisation, notifications, `HydrationStore`.
- `Wello/Views` — écrans SwiftUI (Principal, Historique, Profil) + composants.

## Hors périmètre (Phase 1)

watchOS, Widget iOS, complication Watch — prévus en Phase 2.
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README (lancement, permissions, plancher médical)"
```

---

## Self-Review (effectuée)

**Couverture de la spec :**
- Calcul (base/activité/météo/plancher/plafond) → Tasks 3–7 ✅
- Météo absente → Task 5 ✅ ; fallback poids → Task 8 ✅ ; double comptage (consommé = somme logs) → Task 16 ✅
- Modèles SwiftData → Task 9 ✅
- HealthKit lecture/écriture + dégradation → Task 12 ✅
- Météo Open-Meteo best-effort → Task 13 ✅ ; localisation → Task 14 ✅
- Notifications (fenêtre 7h–21h, post-séance, retard 14h/17h, action 250 ml, désactiver-jour) → Task 15 ✅
- 3 écrans (Principal/Profil/Historique) + jauge + breakdown → Tasks 17–21 ✅
- Permissions Info.plist + capability → Tasks 12/14, README Task 23 ✅
- README → Task 23 ✅
- Hors périmètre Phase 2 (Watch/Widget) explicitement exclu ✅

**Placeholders :** aucun — chaque étape contient le code réel.

**Cohérence des types :** `CalculatorInputs`, `GoalBreakdown`, `WeatherSnapshot`, `résoudrePoids`,
les protocoles de services et leurs méthodes (`minutesEffortDuJour`, `écrireEau`, `météoDuJour`,
`coordonnéesActuelles`, `planifierRappels`…) sont définis avant usage et utilisés à l'identique
dans `HydrationStore` et `WelloApp`.

**Note connue :** `NotificationService` planifie les rappels de retard à heure fixe (14h/17h) sans
relire le consommé au moment du déclenchement (pas de logique conditionnelle live possible en
notification locale) — c'est une simplification assumée de Phase 1, cohérente avec « best-effort ».
````
