# Personnalisation physiologique de l'objectif — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le plancher médical par des termes additifs (grossesse +300, allaitement +700, besoin rénal réglable opt-in), tout en simplifiant la carte « Détail de l'objectif ».

**Architecture:** Le calcul devient 100 % additif : `total = min(4000, base + activité + météo + état physiologique + rénal)`. La logique vit dans WelloKit (pur, testé en CLI) ; l'app SwiftData/SwiftUI lit le profil et affiche les termes.

**Tech Stack:** Swift 6, swift-testing, SwiftData, SwiftUI, package local WelloKit.

**Spec source :** `docs/superpowers/specs/2026-06-04-profil-physiologique-design.md`

---

## Notes d'exécution propres à ce dépôt

- **Pas de git** : ce projet n'est pas un repo. Là où un plan classique committe, on exécute la
  **vérification** correspondante. Il n'y a rien à `git add`.
- **L'app n'est pas compilable en CLI via Xcode** : l'utilisateur build/run dans Xcode. La preuve
  de validité côté app est le **type-check hors Xcode** (commande ci-dessous). Côté WelloKit, on a
  de vrais tests (`swift test`).
- Les fichiers de l'app sont **fortement couplés** (retirer `UserProfile.medicalFloorML` casse
  `HydrationStore`, `ProfileView`, `PreviewSupport` tant que tout n'est pas mis à jour). Les tâches
  app (3→8) se vérifient donc **ensemble** au type-check final (Tâche 9), pas isolément.

**Commande type-check app (depuis la racine `Wello/`) :**
```bash
rm -rf /tmp/wellomod && mkdir -p /tmp/wellomod
xcrun --sdk iphonesimulator swiftc -emit-module -module-name WelloKit \
  -target arm64-apple-ios17.0-simulator \
  WelloKit/Sources/WelloKit/*.swift WelloKit/Sources/WelloKit/Models/*.swift \
  -emit-module-path /tmp/wellomod/WelloKit.swiftmodule
xcrun --sdk iphonesimulator swiftc -typecheck -D DEBUG \
  -enable-upcoming-feature MemberImportVisibility \
  -target arm64-apple-ios17.0-simulator -I /tmp/wellomod \
  Wello/Wello/App/*.swift Wello/Wello/Models/*.swift \
  Wello/Wello/Services/*.swift Wello/Wello/Views/*.swift
```

---

## Carte des fichiers

| Fichier | Action | Responsabilité |
|---|---|---|
| `WelloKit/Sources/WelloKit/Models/PhysiologicalState.swift` | **Créer** | Enum état de vie + bonus EFSA |
| `WelloKit/Sources/WelloKit/Models/CalculatorInputs.swift` | Modifier | Entrées : retirer floor, ajouter état + rénal |
| `WelloKit/Sources/WelloKit/Models/GoalBreakdown.swift` | Modifier | Sortie : retirer floor, ajouter termes additifs |
| `WelloKit/Sources/WelloKit/HydrationCalculator.swift` | Modifier | Calcul tout additif, plafond seul |
| `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` | Modifier | Adapter + cas physio/rénal/plafond |
| `Wello/Wello/Models/UserProfile.swift` | Modifier | Champs état physio + toggle/valeur rénal |
| `Wello/Wello/Models/DailyGoal.swift` | Modifier | Persistance des nouveaux termes |
| `Wello/Wello/Services/HydrationStore.swift` | Modifier | Construire inputs + upsert |
| `Wello/Wello/Views/ProfileView.swift` | Modifier | Sections état physio + rénal |
| `Wello/Wello/Views/BreakdownCard.swift` | Modifier | Lignes additives, plus de plancher |
| `Wello/Wello/Views/OnboardingView.swift` | Modifier | Reformuler la phrase plancher |
| `Wello/Wello/Views/PreviewSupport.swift` | Modifier | Constructions à la nouvelle signature |

---

## Task 1 : Enum `PhysiologicalState` (WelloKit)

**Files:**
- Create: `WelloKit/Sources/WelloKit/Models/PhysiologicalState.swift`
- Test: `WelloKit/Tests/WelloKitTests/PhysiologicalStateTests.swift`

- [ ] **Step 1 : Écrire le test qui échoue**

Créer `WelloKit/Tests/WelloKitTests/PhysiologicalStateTests.swift` :
```swift
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
```

- [ ] **Step 2 : Lancer le test, vérifier l'échec de compilation**

Run: `cd WelloKit && swift test --filter PhysiologicalState`
Expected: échec de compilation (`cannot find 'PhysiologicalState' in scope`).

- [ ] **Step 3 : Implémenter l'enum**

Créer `WelloKit/Sources/WelloKit/Models/PhysiologicalState.swift` :
```swift
/// État physiologique influant sur le besoin en eau (apports additifs EFSA).
/// Exclusif : on est soit dans aucun de ces états, soit dans un seul.
public enum PhysiologicalState: String, Sendable, CaseIterable {
    case aucun
    case grossesse
    case allaitement

    /// Apport additif quotidien d'eau de boisson (ml), valeurs EFSA.
    /// Grossesse : +300 ml. Allaitement : +700 ml (borne haute de 600–700).
    public var bonusML: Int {
        switch self {
        case .aucun:       0
        case .grossesse:   300
        case .allaitement: 700
        }
    }

    /// Libellé court français pour l'affichage.
    public var label: String {
        switch self {
        case .aucun:       "Aucun"
        case .grossesse:   "Enceinte"
        case .allaitement: "Allaitante"
        }
    }
}
```

- [ ] **Step 4 : Lancer le test, vérifier qu'il passe**

Run: `cd WelloKit && swift test --filter PhysiologicalState`
Expected: PASS (3 tests).

---

## Task 2 : Calcul tout additif (WelloKit)

Cette tâche change ensemble les entrées, la sortie, la logique et les tests, pour que le module
reste compilable et `swift test` vert à la fin.

**Files:**
- Modify: `WelloKit/Sources/WelloKit/Models/CalculatorInputs.swift`
- Modify: `WelloKit/Sources/WelloKit/Models/GoalBreakdown.swift`
- Modify: `WelloKit/Sources/WelloKit/HydrationCalculator.swift`
- Modify: `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift`

- [ ] **Step 1 : Réécrire les tests vers la nouvelle API (échouera à compiler)**

Remplacer **tout le contenu** de `WelloKit/Tests/WelloKitTests/HydrationCalculatorTests.swift` par :
```swift
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
```

- [ ] **Step 2 : Lancer les tests, vérifier l'échec de compilation**

Run: `cd WelloKit && swift test`
Expected: échec de compilation (paramètres `physiologicalState`/`renalBonusML` et propriétés
`lifeStageBonusML` inexistants).

- [ ] **Step 3 : Mettre à jour `CalculatorInputs`**

Remplacer **tout le contenu** de `WelloKit/Sources/WelloKit/Models/CalculatorInputs.swift` par :
```swift
/// Entrées du calcul d'objectif d'hydratation. `weather` est optionnel :
/// si la météo est indisponible (réseau/API down), le bonus météo vaut 0.
public struct CalculatorInputs: Sendable, Equatable {
    /// Sexe biologique : fixe la base EFSA (2000 ml homme / 1600 ml femme).
    public let sex: BiologicalSex
    /// Énergie active brûlée à l'effort aujourd'hui (kcal), issue de HealthKit.
    /// Proxy physiologique de la perte sudorale (intensité, pas seulement durée).
    public let activeEnergyKcal: Double
    public let weather: WeatherSnapshot?
    /// État physiologique (grossesse/allaitement) → terme additif EFSA.
    public let physiologicalState: PhysiologicalState
    /// Besoin rénal additif (lithiase). 0 si le suivi rénal est désactivé dans le profil.
    public let renalBonusML: Int

    public init(sex: BiologicalSex, activeEnergyKcal: Double, weather: WeatherSnapshot?,
                physiologicalState: PhysiologicalState = .aucun, renalBonusML: Int = 0) {
        self.sex = sex
        self.activeEnergyKcal = activeEnergyKcal
        self.weather = weather
        self.physiologicalState = physiologicalState
        self.renalBonusML = renalBonusML
    }
}
```

- [ ] **Step 4 : Mettre à jour `GoalBreakdown`**

Remplacer **tout le contenu** de `WelloKit/Sources/WelloKit/Models/GoalBreakdown.swift` par :
```swift
/// Résultat détaillé du calcul, pour affichage du breakdown dans l'UI.
/// Modèle 100 % additif : le total est la somme des termes, bridée au plafond de sécurité.
public struct GoalBreakdown: Sendable, Equatable {
    public let baseML: Int
    public let activityBonusML: Int
    public let weatherBonusML: Int
    /// Terme additif lié à l'état physiologique (grossesse +300 / allaitement +700 / aucun 0).
    public let lifeStageBonusML: Int
    /// Terme additif lié au besoin rénal (lithiase). 0 si désactivé.
    public let renalBonusML: Int
    public let totalML: Int
    /// Vrai si l'objectif a été bridé au plafond de sécurité (anti-hyperhydratation).
    public let plafondAppliqué: Bool

    /// Besoin physiologique = somme de tous les termes additifs (= total avant plafond).
    public var physiologicalML: Int {
        baseML + activityBonusML + weatherBonusML + lifeStageBonusML + renalBonusML
    }

    public init(baseML: Int, activityBonusML: Int, weatherBonusML: Int, lifeStageBonusML: Int,
                renalBonusML: Int, totalML: Int, plafondAppliqué: Bool) {
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.lifeStageBonusML = lifeStageBonusML
        self.renalBonusML = renalBonusML
        self.totalML = totalML
        self.plafondAppliqué = plafondAppliqué
    }
}
```

- [ ] **Step 5 : Mettre à jour `HydrationCalculator`**

Remplacer **tout le contenu** de `WelloKit/Sources/WelloKit/HydrationCalculator.swift` par :
```swift
/// Calcul pur de l'objectif d'hydratation quotidien.
/// Aucune dépendance Apple framework : entièrement testable hors Xcode.
public struct HydrationCalculator: Sendable {

    /// Constantes médicales/algorithmiques nommées (cf. spec).
    public enum Constantes {
        /// Cible de boisson EFSA 2010 (eau totale 2,5 L / 2,0 L, dont ~80 % via les boissons).
        public static let baseHommeML = 2000
        public static let baseFemmeML = 1600
        /// ml d'eau par kcal d'énergie active. Base scientifique : évaporer 1 mL de sueur
        /// dissipe ~0,58 kcal ; à l'effort ~75-80 % de l'énergie devient chaleur, dissipée
        /// majoritairement par la sueur → ~1 mL/kcal (coefficient conservateur).
        public static let mlParKcal = 1.0
        public static let plafondActivité = 1000
        /// Température ressentie (°C) en dessous de laquelle aucun bonus météo (zone de confort).
        public static let seuilConfortRessentiC = 27.0
        /// ml d'eau supplémentaires par °C ressenti au-dessus du seuil de confort.
        public static let mlParDegréRessenti = 50.0
        /// Plafond du bonus météo (≈ +12°C ressentis au-dessus du confort).
        public static let plafondMétéo = 600
        /// Plafond de sécurité global : on n'affiche jamais d'objectif supérieur.
        public static let plafondGlobal = 4000
    }

    public init() {}

    public func calculate(_ inputs: CalculatorInputs) -> GoalBreakdown {
        let base = inputs.sex == .homme ? Constantes.baseHommeML : Constantes.baseFemmeML

        let activité = min(Int((inputs.activeEnergyKcal * Constantes.mlParKcal).rounded()), Constantes.plafondActivité)

        let météo = bonusMétéo(inputs.weather)

        let étatPhysio = inputs.physiologicalState.bonusML
        // Garde-fou : un besoin rénal négatif (saisie aberrante) ne retire jamais d'eau.
        let rénal = max(0, inputs.renalBonusML)

        let physiologique = base + activité + météo + étatPhysio + rénal
        // Plafond de sécurité anti-hyperhydratation : unique garde-fou (plus de plancher).
        let total = min(Constantes.plafondGlobal, physiologique)

        return GoalBreakdown(
            baseML: base,
            activityBonusML: activité,
            weatherBonusML: météo,
            lifeStageBonusML: étatPhysio,
            renalBonusML: rénal,
            totalML: total,
            plafondAppliqué: physiologique > Constantes.plafondGlobal
        )
    }

    private func bonusMétéo(_ weather: WeatherSnapshot?) -> Int {
        guard let w = weather else { return 0 }   // météo absente → bonus 0
        // Montée linéaire à partir du seuil de confort, plafonnée. La température ressentie
        // combine déjà chaleur + humidité + vent (cf. WeatherSnapshot).
        let excès = w.apparentTemperatureC - Constantes.seuilConfortRessentiC
        guard excès > 0 else { return 0 }
        return min(Int((excès * Constantes.mlParDegréRessenti).rounded()), Constantes.plafondMétéo)
    }
}
```

- [ ] **Step 6 : Lancer toute la suite WelloKit, vérifier le vert**

Run: `cd WelloKit && swift test`
Expected: PASS (tous les suites, dont `PhysiologicalState` et `HydrationCalculator`).

---

## Task 3 : Modèle `UserProfile` (app)

**Files:**
- Modify: `Wello/Wello/Models/UserProfile.swift`

- [ ] **Step 1 : Remplacer le contenu du modèle**

Remplacer **tout le contenu** de `Wello/Wello/Models/UserProfile.swift` par :
```swift
import Foundation
import SwiftData
import WelloKit

/// Profil unique de l'utilisateur (app mono-utilisateur).
@Model
final class UserProfile {
    var remindersEnabled: Bool
    /// Sexe biologique pour la base EFSA. Stocké en brut (String?) pour la migration légère
    /// SwiftData ; nil = pas encore renseigné (force l'onboarding). Exposé via `sexe`.
    var sexeRaw: String? = nil
    /// État physiologique (grossesse/allaitement). Brut pour la migration légère ; nil = aucun.
    var etatPhysioRaw: String? = nil
    /// Suivi rénal (lithiase) : opt-in. Quand actif, ajoute `renalBonusML` à l'objectif.
    var renalLithiase: Bool = false
    /// Apport rénal additif (ml) appliqué quand `renalLithiase` est actif. Réglable 500–1500.
    var renalBonusML: Int = 1000
    /// Montants des 3 boutons d'ajout rapide (personnalisables). Défauts inline pour
    /// la migration légère SwiftData.
    var quickAdd1: Int = 150
    var quickAdd2: Int = 250
    var quickAdd3: Int = 500
    var updatedAt: Date

    /// Les 3 montants rapides dans l'ordre, pour itération en UI.
    var quickAdds: [Int] { [quickAdd1, quickAdd2, quickAdd3] }

    /// Sexe biologique, ou nil si non renseigné.
    var sexe: BiologicalSex? {
        get { sexeRaw.flatMap(BiologicalSex.init(rawValue:)) }
        set { sexeRaw = newValue?.rawValue }
    }

    /// État physiologique (défaut : aucun).
    var etatPhysio: PhysiologicalState {
        get { etatPhysioRaw.flatMap(PhysiologicalState.init(rawValue:)) ?? .aucun }
        set { etatPhysioRaw = newValue.rawValue }
    }

    /// Apport rénal effectif appliqué au calcul (0 si le suivi est désactivé).
    var renalBonusEffectifML: Int { renalLithiase ? renalBonusML : 0 }

    init(remindersEnabled: Bool = true,
         quickAdd1: Int = 150, quickAdd2: Int = 250, quickAdd3: Int = 500,
         updatedAt: Date = .now) {
        self.remindersEnabled = remindersEnabled
        self.quickAdd1 = quickAdd1
        self.quickAdd2 = quickAdd2
        self.quickAdd3 = quickAdd3
        self.updatedAt = updatedAt
    }
}
```

Note : l'init ne prend plus `medicalFloorML`. Migration légère SwiftData (attribut supprimé +
attributs ajoutés avec défaut).

---

## Task 4 : Modèle `DailyGoal` (app)

**Files:**
- Modify: `Wello/Wello/Models/DailyGoal.swift`

- [ ] **Step 1 : Remplacer le contenu du modèle**

Remplacer **tout le contenu** de `Wello/Wello/Models/DailyGoal.swift` par :
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
    /// Terme additif état physiologique (grossesse/allaitement). Défaut inline (migration légère).
    var lifeStageBonusML: Int = 0
    /// Terme additif besoin rénal (0 si désactivé). Défaut inline (migration légère).
    var renalBonusML: Int = 0
    var totalML: Int
    var calculatedAt: Date

    init(date: Date, baseML: Int, activityBonusML: Int, weatherBonusML: Int,
         lifeStageBonusML: Int = 0, renalBonusML: Int = 0, totalML: Int, calculatedAt: Date = .now) {
        self.date = date
        self.baseML = baseML
        self.activityBonusML = activityBonusML
        self.weatherBonusML = weatherBonusML
        self.lifeStageBonusML = lifeStageBonusML
        self.renalBonusML = renalBonusML
        self.totalML = totalML
        self.calculatedAt = calculatedAt
    }
}
```

---

## Task 5 : Branchement `HydrationStore` (app)

**Files:**
- Modify: `Wello/Wello/Services/HydrationStore.swift:102-103` (construction des inputs)
- Modify: `Wello/Wello/Services/HydrationStore.swift:252-268` (upsert)

- [ ] **Step 1 : Construire les inputs avec l'état physio + rénal**

Remplacer dans `refreshToday(force:)` :
```swift
        let inputs = CalculatorInputs(sex: sexe, activeEnergyKcal: énergie,
                                      weather: snapshot, medicalFloorML: profil.medicalFloorML)
```
par :
```swift
        let inputs = CalculatorInputs(sex: sexe, activeEnergyKcal: énergie, weather: snapshot,
                                      physiologicalState: profil.etatPhysio,
                                      renalBonusML: profil.renalBonusEffectifML)
```

- [ ] **Step 2 : Mapper les nouveaux termes dans `upsertDailyGoal`**

Remplacer **tout le corps** de `upsertDailyGoal(_:)` par :
```swift
    private func upsertDailyGoal(_ r: GoalBreakdown) {
        let jour = Calendar.current.startOfDay(for: .now)
        let descripteur = FetchDescriptor<DailyGoal>(predicate: #Predicate { $0.date == jour })

        if let goal = try? modelContext.fetch(descripteur).first {
            goal.baseML = r.baseML
            goal.activityBonusML = r.activityBonusML
            goal.weatherBonusML = r.weatherBonusML
            goal.lifeStageBonusML = r.lifeStageBonusML
            goal.renalBonusML = r.renalBonusML
            goal.totalML = r.totalML
            goal.calculatedAt = .now
        } else {
            let goal = DailyGoal(date: jour, baseML: r.baseML, activityBonusML: r.activityBonusML,
                                 weatherBonusML: r.weatherBonusML,
                                 lifeStageBonusML: r.lifeStageBonusML, renalBonusML: r.renalBonusML,
                                 totalML: r.totalML)
            modelContext.insert(goal)
        }
    }
```

---

## Task 6 : UI Profil — sections état physio + rénal (app)

**Files:**
- Modify: `Wello/Wello/Views/ProfileView.swift`

- [ ] **Step 1 : Remplacer la section « Plancher médical » par état physio + rénal**

Dans `ProfileView.body`, **supprimer** la section « Plancher médical » (le bloc
`Section { Stepper(... profil.medicalFloorML ...) } footer: { Text("Plafonné à 4000 ml...") }`)
et insérer à sa place les deux sections suivantes :
```swift
                    Section {
                        Picker(selection: Binding(get: { profil.etatPhysio },
                                                  set: { profil.etatPhysio = $0; profil.updatedAt = .now
                                                         Task { await store.refreshToday(force: true) } })) {
                            Text("Aucun").tag(PhysiologicalState.aucun)
                            Text("Enceinte").tag(PhysiologicalState.grossesse)
                            Text("Allaitante").tag(PhysiologicalState.allaitement)
                        } label: {
                            label("État physiologique", profil.etatPhysio.label,
                                  icon: "figure.stand", teinte: .pink)
                        }
                    } footer: {
                        Text("Ajoute l'apport recommandé (EFSA) : +300 ml enceinte, +700 ml allaitante.")
                            .font(.system(.caption, design: .rounded))
                    }

                    Section {
                        Toggle(isOn: Binding(get: { profil.renalLithiase },
                                             set: { profil.renalLithiase = $0; profil.updatedAt = .now
                                                    Task { await store.refreshToday(force: true) } })) {
                            label("Calculs rénaux (lithiase)", nil, icon: "cross.case.fill", teinte: .purple)
                        }
                        if profil.renalLithiase {
                            Stepper(value: Binding(get: { profil.renalBonusML },
                                                   set: { profil.renalBonusML = $0; profil.updatedAt = .now
                                                          Task { await store.refreshToday(force: true) } }),
                                    in: 500...1500, step: 100) {
                                label("Apport rénal", "+\(profil.renalBonusML) ml",
                                      icon: "drop.fill", teinte: .purple)
                            }
                        }
                    } footer: {
                        Text("Vise un apport plus élevé pour la prévention des calculs. À régler selon avis médical.")
                            .font(.system(.caption, design: .rounded))
                    }
```

Note : la fonction privée `label(_:_:icon:teinte:)` existe déjà dans `ProfileView` ; on la réutilise.

---

## Task 7 : UI Home — carte « Détail de l'objectif » (app)

**Files:**
- Modify: `Wello/Wello/Views/BreakdownCard.swift`

- [ ] **Step 1 : Remplacer le contenu de la carte**

Remplacer **tout le contenu** de `Wello/Wello/Views/BreakdownCard.swift` par :
```swift
import SwiftUI
import WelloKit

/// Carte détaillant la composition de l'objectif du jour (100 % additif).
struct BreakdownCard: View {
    let breakdown: GoalBreakdown
    /// Vrai si la météo n'a pas pu être récupérée (le bonus à 0 n'est alors pas significatif).
    var météoIndisponible: Bool = false
    /// Libellé de la ligne état physiologique (selon l'état actif). nil si aucun.
    var libelléÉtatPhysio: String? = nil

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 14) {
                Text("Détail de l'objectif")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(WelloTheme.ink)

                // Termes additifs : base + bonus, dans l'ordre. Optionnels masqués si nuls.
                ligne("Base (EFSA)", breakdown.baseML, icon: "person.fill", teinte: WelloTheme.accent)
                ligne("Activité", breakdown.activityBonusML, icon: "figure.run", teinte: .orange, signe: "+")
                ligne("Météo", breakdown.weatherBonusML, icon: "cloud.sun.fill", teinte: .yellow, signe: "+")
                if breakdown.lifeStageBonusML > 0 {
                    ligne(libelléÉtatPhysio ?? "État physiologique", breakdown.lifeStageBonusML,
                          icon: "figure.stand", teinte: .pink, signe: "+")
                }
                if breakdown.renalBonusML > 0 {
                    ligne("Besoin rénal", breakdown.renalBonusML,
                          icon: "cross.case.fill", teinte: .purple, signe: "+")
                }

                Divider().overlay(WelloTheme.inkSoft.opacity(0.25))

                HStack {
                    Text("Total")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(WelloTheme.ink)
                    Spacer()
                    Text("\(breakdown.totalML) ml")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(WelloTheme.accentDeep)
                }

                if météoIndisponible {
                    badge("Météo indisponible — bonus non appliqué", "wifi.slash", .gray)
                }
                if breakdown.plafondAppliqué {
                    badge("Bridé au plafond de sécurité (4000 ml)", "exclamationmark.shield.fill", .orange)
                }
            }
        }
    }

    private func ligne(_ libellé: String, _ valeur: Int, icon: String, teinte: Color,
                       signe: String = "") -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(teinte)
                .frame(width: 30, height: 30)
                .background(teinte.opacity(0.15), in: Circle())
            Text(libellé)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(WelloTheme.inkSoft)
            Spacer()
            Text("\(signe)\(valeur) ml")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(WelloTheme.ink)
        }
    }

    private func badge(_ texte: String, _ icon: String, _ teinte: Color) -> some View {
        Label(texte, systemImage: icon)
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(teinte)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(teinte.opacity(0.12), in: Capsule())
    }
}

#if DEBUG
#Preview {
    BreakdownCard(breakdown: GoalBreakdown(baseML: 1600, activityBonusML: 200, weatherBonusML: 300,
                                           lifeStageBonusML: 700, renalBonusML: 0, totalML: 2800,
                                           plafondAppliqué: false),
                  libelléÉtatPhysio: "Allaitement")
    .padding()
    .welloBackground()
}
#endif
```

- [ ] **Step 2 : Passer le libellé de l'état physio depuis `MainView`**

Dans `Wello/Wello/Views/MainView.swift`, la carte est instanciée ainsi :
```swift
                        BreakdownCard(breakdown: breakdown,
                                      météoIndisponible: store.météoIndisponible)
```
La remplacer par (le libellé vient du profil courant) :
```swift
                        BreakdownCard(breakdown: breakdown,
                                      météoIndisponible: store.météoIndisponible,
                                      libelléÉtatPhysio: profils.first?.etatPhysio.label)
```
`MainView` a déjà `@Query private var profils: [UserProfile]` et `import WelloKit`, donc
`etatPhysio.label` est accessible sans import supplémentaire.

---

## Task 8 : Onboarding + Previews (app)

**Files:**
- Modify: `Wello/Wello/Views/OnboardingView.swift:20`
- Modify: `Wello/Wello/Views/PreviewSupport.swift:17,24-26`

- [ ] **Step 1 : Reformuler la phrase d'onboarding**

Remplacer la ligne :
```swift
             texte: "Wello ajuste ton objectif du jour selon ton sexe, ton activité (Santé) et la météo — sans jamais descendre sous ton plancher médical."),
```
par :
```swift
             texte: "Wello ajuste ton objectif du jour selon ton sexe, ton activité (Santé), la météo et ta situation (grossesse, allaitement, besoin rénal)."),
```

- [ ] **Step 2 : Mettre à jour `PreviewSupport`**

Remplacer :
```swift
        let profil = UserProfile(medicalFloorML: 2500)
```
par :
```swift
        let profil = UserProfile()
```

Puis remplacer la création du `DailyGoal` d'hier :
```swift
        ctx.insert(DailyGoal(date: Calendar.current.startOfDay(for: hier),
                             baseML: 2730, activityBonusML: 300, weatherBonusML: 500,
                             medicalFloorML: 2500, totalML: 3530))
```
par :
```swift
        ctx.insert(DailyGoal(date: Calendar.current.startOfDay(for: hier),
                             baseML: 2000, activityBonusML: 300, weatherBonusML: 500,
                             lifeStageBonusML: 0, renalBonusML: 0, totalML: 2800))
```

---

## Task 9 : Vérification finale

**Files:** aucun (vérification).

- [ ] **Step 1 : Tests WelloKit verts**

Run: `cd WelloKit && swift test`
Expected: PASS (toutes les suites).

- [ ] **Step 2 : Type-check de l'app hors Xcode**

Run (depuis la racine `Wello/`) :
```bash
rm -rf /tmp/wellomod && mkdir -p /tmp/wellomod
xcrun --sdk iphonesimulator swiftc -emit-module -module-name WelloKit \
  -target arm64-apple-ios17.0-simulator \
  WelloKit/Sources/WelloKit/*.swift WelloKit/Sources/WelloKit/Models/*.swift \
  -emit-module-path /tmp/wellomod/WelloKit.swiftmodule
xcrun --sdk iphonesimulator swiftc -typecheck -D DEBUG \
  -enable-upcoming-feature MemberImportVisibility \
  -target arm64-apple-ios17.0-simulator -I /tmp/wellomod \
  Wello/Wello/App/*.swift Wello/Wello/Models/*.swift \
  Wello/Wello/Services/*.swift Wello/Wello/Views/*.swift
```
Expected: 0 erreur.

- [ ] **Step 3 : Recherche de références résiduelles au plancher**

Run: `grep -rn "medicalFloor\|plancher\|Plancher\|plancherContraignant\|seuilPlancher" Wello/Wello WelloKit/Sources --include="*.swift"`
Expected: aucune correspondance (hors éventuels commentaires de doc historiques volontaires).

---

## Self-review (auteur du plan)

- **Couverture spec** : enum état (T1) ✓ ; tout-additif + suppression plancher (T2) ✓ ;
  UserProfile état+rénal (T3) ✓ ; DailyGoal (T4) ✓ ; HydrationStore inputs+upsert (T5) ✓ ;
  ProfileView sections (T6) ✓ ; BreakdownCard refonte (T7) ✓ ; onboarding+previews (T8) ✓ ;
  vérif swift test + type-check (T9) ✓.
- **Cohérence des types** : `physiologicalState`/`renalBonusML` (inputs), `lifeStageBonusML`/
  `renalBonusML`/`plafondAppliqué` (breakdown), `etatPhysio`/`renalLithiase`/`renalBonusML`/
  `renalBonusEffectifML` (profil) — utilisés identiquement partout. `GoalBreakdown.init` (ordre :
  base, activity, weather, lifeStage, renal, total, plafondAppliqué) cohérent entre T2, T7, T8.
- **Pas de placeholder** : tout le code est fourni en entier.
- **Note migration** : suppression de `medicalFloorML` + ajout d'attributs à défaut inline →
  migration légère SwiftData ; acceptable en mono-utilisateur (l'objectif d'un profil sans souci
  rénal repasse à la base EFSA, comportement voulu).
