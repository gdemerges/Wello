# Design — Personnalisation physiologique de l'objectif (grossesse, allaitement, lithiase rénale)

Date : 2026-06-04
Statut : validé (brainstorming), prêt pour plan d'implémentation

## Contexte et déclencheur

Lecture d'un article (Le Parisien, 26/05/2026) reprenant les apports de référence EFSA et les
recommandations des autorités sanitaires françaises. La comparaison avec `HydrationCalculator` a
confirmé que les bases de Wello (1600 ml femme / 2000 ml homme d'eau de boisson) sont alignées sur
ces sources. L'article a toutefois mis en lumière des **profils non couverts** par l'app :
femmes enceintes et allaitantes. En parallèle, on veut clarifier la présentation de l'objectif sur
l'accueil.

## Décisions de cadrage (issues du brainstorming)

1. **Tout devient additif.** L'objectif est la somme de termes explicites, plafonnée à 4000 ml.
   Le concept de **plancher médical (minimum garanti) est supprimé** du modèle, du calcul et de
   l'UI. Seul le plafond 4000 subsiste comme garde-fou.
2. **Grossesse / allaitement** : état de profil **exclusif** (aucun / enceinte / allaitante),
   modélisé comme terme additif aux valeurs EFSA : **+300 ml** (grossesse), **+700 ml**
   (allaitement, borne haute de la fourchette 600–700).
3. **Lithiase rénale (calculs)** : **toggle opt-in** dans le profil, éteint par défaut. Quand il
   est allumé, il ajoute un terme **« Besoin rénal »** réglable (stepper 500–1500 ml, pas de 100,
   défaut 1000). Éteint → aucun terme rénal, aucune ligne affichée.
4. **Hors périmètre, volontairement** : sénior (plancher, pas un ajout), fièvre / température
   corporelle (ponctuel, pas un état de profil durable), enfants (pas d'utilisateur cible),
   insuffisance rénale avec restriction hydrique (dangereux à modéliser sans avis médical).

## Conséquence de sécurité actée

Supprimer le plancher médical retire le **minimum garanti** : l'objectif d'une personne inactive
par temps doux retombe à sa base EFSA (1600 / 2000 ml). C'est médicalement correct (c'est la base
de référence), mais c'est un changement de comportement assumé. L'app reste mono-utilisateur et
le besoin de minimum élevé spécifique (lithiase) est désormais couvert par le toggle rénal.

## 1. Logique de calcul (WelloKit — pur, testable en CLI)

### Nouveau type `Models/PhysiologicalState.swift`

```swift
public enum PhysiologicalState: String, Sendable, CaseIterable {
    case aucun
    case grossesse
    case allaitement

    /// Apport additif quotidien (eau de boisson), valeurs EFSA.
    public var bonusML: Int {
        switch self {
        case .aucun:       0
        case .grossesse:   300
        case .allaitement: 700
        }
    }

    public var label: String {
        switch self {
        case .aucun:       "Aucun"
        case .grossesse:   "Enceinte"
        case .allaitement: "Allaitante"
        }
    }
}
```

### `CalculatorInputs`

- **Retirer** `medicalFloorML`.
- **Ajouter** `physiologicalState: PhysiologicalState`.
- **Ajouter** `renalBonusML: Int` (0 si le toggle lithiase est éteint ; sinon la valeur du stepper).

### `HydrationCalculator`

```
physiologique = base + activité + météo + physiologicalState.bonusML + renalBonusML
total         = min(plafondGlobal, physiologique)     // plafondGlobal = 4000
```

- Supprimer la branche `max(medicalFloorML, physiologique)` et le drapeau `plancherContraignant`.
- Conserver `plafondGlobal = 4000` et la détection `plafondAppliqué`.
- Les constantes `baseHommeML`, `baseFemmeML`, `mlParKcal`, `plafondActivité`,
  `seuilConfortRessentiC`, `mlParDegréRessenti`, `plafondMétéo` sont inchangées.

### `GoalBreakdown`

- **Retirer** `medicalFloorML` et `plancherContraignant`.
- **Ajouter** `lifeStageBonusML: Int` (grossesse/allaitement) et `renalBonusML: Int`.
- `physiologicalML` = `baseML + activityBonusML + weatherBonusML + lifeStageBonusML + renalBonusML`
  (= total avant plafond).
- Conserver `totalML` et `plafondAppliqué`.

### Tests (`HydrationCalculatorTests`)

- Adapter les cas existants à la nouvelle signature (plus de `medicalFloorML`).
- Ajouter : grossesse (+300), allaitement (+700), `aucun` (+0), besoin rénal additif,
  cumul (état physio + rénal), application du plafond 4000.

## 2. Données app (SwiftData)

### `UserProfile`

- **Retirer** `medicalFloorML`.
- **Ajouter** :
  - `etatPhysioRaw: String? = nil`, exposé via `var etatPhysio: PhysiologicalState`
    (get : `etatPhysioRaw.flatMap(PhysiologicalState.init(rawValue:)) ?? .aucun` ; set : stocke le
    rawValue) — même pattern de migration légère que `sexe`.
  - `renalLithiase: Bool = false`.
  - `renalBonusML: Int = 1000`.

### `DailyGoal`

- **Retirer** `medicalFloorML`.
- **Ajouter** `lifeStageBonusML: Int` et `renalBonusML: Int`.
- Migration légère SwiftData (suppression d'attribut + ajouts avec valeur par défaut). Acceptable
  en mono-utilisateur.

### `HydrationStore`

- Construire `CalculatorInputs` avec :
  - `physiologicalState: profil.etatPhysio`
  - `renalBonusML: profil.renalLithiase ? profil.renalBonusML : 0`
  - (plus de `medicalFloorML`).
- `upsertDailyGoal` mappe `lifeStageBonusML` et `renalBonusML` du `GoalBreakdown` vers le
  `DailyGoal`.

## 3. UI Profil (`ProfileView`)

- **Supprimer** la section « Plancher médical » (Stepper + footer).
- **Ajouter** section « État physiologique » : `Picker` *Aucun / Enceinte / Allaitante* lié à
  `profil.etatPhysio`, déclenchant `store.refreshToday(force: true)` ; footer rappelant les
  valeurs (+300 / +700 ml, EFSA).
- **Ajouter** section « Calculs rénaux » :
  - `Toggle` « Lithiase / calculs rénaux » lié à `profil.renalLithiase`.
  - `Stepper` conditionnel (affiché seulement si le toggle est ON) : 500–1500 ml, pas de 100, lié
    à `profil.renalBonusML` ; footer expliquant qu'il vise un apport total plus élevé pour la
    prévention des calculs, à régler selon avis médical.
  - Toute modification → `store.refreshToday(force: true)`.

## 4. UI Home — carte « Détail de l'objectif » (`BreakdownCard`)

Lignes additives, dans l'ordre ; les optionnelles ne s'affichent que si `> 0` :

```
Base (EFSA)                 2000 ml
Activité                   + 300 ml
Météo                      + 200 ml
Grossesse / Allaitement    + 300 ml      (si etatPhysio ≠ aucun ; libellé selon l'état)
Besoin rénal               + 1000 ml     (si renalBonusML > 0)
──────────────────────────────────────
Total                       3800 ml
```

- **Supprimer** la ligne « Plancher médical (seuil minimum) », la fonction `seuilPlancher`, et le
  badge « Objectif relevé au plancher médical ».
- **Supprimer** le sous-total intermédiaire « Besoin physiologique » (désormais identique au Total
  hors plafond).
- **Conserver** le badge « Bridé au plafond de sécurité (4000 ml) » et le badge
  « Météo indisponible ».
- Icône/teinte des nouvelles lignes : à aligner sur le style existant (pastille colorée), p. ex.
  `figure.stand`/rose pour l'état physio, `cross.case.fill`/pourpre pour le besoin rénal.

### Onboarding (`OnboardingView`)

Reformuler la phrase mentionnant « plancher médical » pour décrire la nouvelle logique, p. ex. :
« Wello ajuste ton objectif du jour selon ton sexe, ton activité (Santé), la météo et ta situation
(grossesse, allaitement, besoin rénal). »

### Previews (`PreviewSupport`, `#Preview` de `BreakdownCard`)

Mettre à jour les constructions de `UserProfile` et `GoalBreakdown` à la nouvelle signature.

## Vérification

- `cd WelloKit && swift test` → vert (cas existants adaptés + nouveaux cas physio/rénal/plafond).
- Type-check iOS hors Xcode (procédure du CLAUDE.md) → 0 erreur.

## Hors périmètre

Sénior, fièvre / température corporelle, enfants, insuffisance rénale (restriction hydrique),
watchOS / widget (Phase 2).
