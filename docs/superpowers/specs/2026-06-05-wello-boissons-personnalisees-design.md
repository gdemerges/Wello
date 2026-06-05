# Wello — Boissons personnalisées (« Wello+ ») — Design

**Date :** 2026-06-05
**Statut :** Validé pour implémentation
**Pré-requis :** Mode premium « Wello+ » livré — voir `2026-06-04-wello-premium-design.md`

## Contexte & objectif

L'infrastructure premium (StoreKit, `EntitlementStore`, paywall, gating) et deux features
payantes (historique illimité, analyses) sont livrées. Ce spec couvre la **prochaine feature
Wello+ : les boissons personnalisées**, déjà réservée dans l'enum par `PremiumFeature.customDrinks`.

**Principe :** toutes les boissons n'hydratent pas autant. Chaque type de boisson porte un
**coefficient d'hydratation** ; l'**hydratation effective** d'une prise vaut
`volume × coefficient`. C'est cette valeur effective qui compte vers l'objectif et alimente la
jauge. L'eau (coefficient 1.0) reste le geste **gratuit**, strictement inchangé.

**Posture produit :** 100 % local, aucun backend. Le cœur gratuit (eau) reste excellent ; les
boissons enrichissent le suivi pour les utilisateurs Wello+.

## Carte des paliers (rappel)

| Capacité | Gratuit | Wello+ |
|---|---|---|
| Saisie d'eau (boutons rapides + feuille « Autre ») | ✅ | ✅ |
| **Types de boissons + coefficients (café/thé/alcool…)** | — | ✅ *(ce spec)* |
| **Édition des coefficients** | — | ✅ *(ce spec)* |

## Décisions validées (brainstorming)

1. **Catalogue fixe + coefficients éditables.** Liste de types prédéfinis avec coefficients de
   référence préremplis ; l'utilisateur peut ajuster chaque coefficient. Pas de création de
   boissons custom (YAGNI pour ce lancement).
2. **Coefficients négatifs autorisés.** L'alcool fort peut avoir un coefficient négatif :
   enregistrer un spiritueux fait reculer l'hydratation effective du jour. La jauge et le
   « consommé » affichés sont **bornés à ≥ 0** ; HealthKit ne reçoit jamais de valeur négative.
3. **Feuille de saisie dédiée.** Les 3 boutons rapides loggent toujours de l'eau (gratuit,
   inchangé). La pilule « Autre » ouvre la feuille de saisie : en Wello+ elle propose le choix
   du type de boisson + la quantité ; en gratuit elle reste eau-seule + une carte de teasing.

## Architecture

Tout se coule dans les patterns existants : **logique pure dans `WelloKit`**, **store
`@Observable` injecté via `.environment`**, **gating via `EntitlementStore.isUnlocked(_:)`**.

### Logique pure — `WelloKit/Sources/WelloKit/`

`Drink.swift` (nouveau) :

- `enum DrinkType: String, Sendable, CaseIterable` — un cas par boisson. Chaque cas expose :
  - `label: String` (FR), `icon: String` (SF Symbol), `defaultCoefficient: Double`.
- `effectiveHydrationML(volumeML: Int, coefficient: Double) -> Int` — `(volume × coeff)`
  arrondi au plus proche. **Peut être négatif** (boisson déshydratante).
- `resolveCoefficient(default: Double, override: Double?) -> Double` — renvoie l'override s'il
  existe sinon le défaut, **borné à `[-1.0 … 1.5]`** (`coefficientRange`).
- `clampedDayTotal(_ sum: Int) -> Int` = `max(0, sum)` — le « consommé » affiché ne descend
  jamais sous 0.

**Catalogue de référence** (valeurs heuristiques, *non médicales*, éditables) :

| `DrinkType` (rawValue) | label | icône | coeff |
|---|---|---|---|
| `water` | Eau | `drop.fill` | 1.0 |
| `sparkling` | Eau gazeuse | `bubbles.and.sparkles` | 1.0 |
| `herbalTea` | Tisane | `leaf.fill` | 1.0 |
| `milk` | Lait | `cup.and.saucer.fill` | 1.0 |
| `tea` | Thé | `cup.and.saucer.fill` | 0.9 |
| `coffee` | Café | `cup.and.saucer.fill` | 0.8 |
| `juice` | Jus de fruits | `waterbottle.fill` | 0.85 |
| `soda` | Soda | `waterbottle.fill` | 0.85 |
| `energy` | Boisson énergisante | `bolt.fill` | 0.7 |
| `beer` | Bière | `mug.fill` | 0.5 |
| `wine` | Vin | `wineglass.fill` | 0.0 |
| `spirits` | Spiritueux | `wineglass.fill` | -0.5 |

`water` est toujours le 1ᵉʳ cas (défaut). Les icônes doivent exister sur iOS 17+ ; un repli
neutre (`drop.fill`) est acceptable si l'une manque à la compilation.

### Modèle & migration — `HydrationLog`

Deux champs ajoutés, **défauts inline** (migration légère SwiftData, comme `quickAdd1` /
`renalLithiase`) :

- `var drinkType: String = "water"` — rawValue du `DrinkType`.
- `var coefficient: Double = 1.0` — **snapshot du coefficient résolu au moment de la prise**.
  Éditer un coefficient plus tard **ne réécrit jamais l'historique** (intégrité des données
  passées, comme un reçu).
- `var effectiveML: Int { effectiveHydrationML(volumeML: amountML, coefficient: coefficient) }`
  (computed, via `WelloKit`).

Les prises existantes et les imports HealthKit prennent `water` / 1.0 → `effectiveML ==
amountML`. **Aucun changement de comportement pour un utilisateur gratuit.**

### Coefficients édités — `DrinkCatalog` (`Wello/Wello/Services/`)

`@MainActor @Observable final class DrinkCatalog`, injecté dans `WelloApp` via `.environment`
(comme `EntitlementStore`). Adossé à `UserDefaults` (`[rawValue: Double]`).

- `coefficient(for: DrinkType) -> Double` — coefficient résolu+borné (via
  `resolveCoefficient`).
- `setCoefficient(_:for:)` — persiste un override.
- `reset(_:)` — supprime l'override (retour au défaut).
- `isCustomized(_:) -> Bool` — pour afficher un badge « modifié » / activer « Réinitialiser ».

Lu par la feuille de saisie (pour snapshoter le coefficient au log) et par l'éditeur du Profil.

### Consommé = hydratation effective

On remplace les sommes de `amountML` par des sommes de `effectiveML`, avec `clampedDayTotal`
à l'affichage, partout où l'on calcule le « consommé » :

- `HydrationStore.consomméAujourdhui()` (sert aux rappels).
- `MainView` (jauge du jour).
- `HistoryView` (consommation par jour, graphe, stats, séries).
- `DayDetailView` (total du jour).
- Alimentation des Analyses (`HydrationStats` reçoit déjà des `consumedML` agrégés).

En gratuit, toute prise est de l'eau (coeff 1.0) → `effectiveML == amountML` → **résultat
identique à l'existant**.

## UX

### Feuille de saisie (« Autre »)

- **Wello+** : `Picker` du type de boisson + `Stepper` de quantité. L'en-tête affiche
  l'**effectif live** (« ≈ 200 ml hydratants ») dès que le coefficient ≠ 1.0. « Ajouter » →
  log du **volume brut** avec le **snapshot** du coefficient résolu.
- **Gratuit** : feuille eau-seule inchangée + `PremiumGateCard` (« Café, thé, alcool… au-delà
  de l'eau ») qui ouvre le paywall (bénéfice : boissons personnalisées).

### Détail du jour (`DayDetailView`)

Chaque ligne montre l'**icône + le nom** de la boisson et le volume brut ; si le coefficient
≠ 1.0, l'effectif (« 250 ml de café · ≈ 200 ml »). Total du jour = effectif.

### Profil — section « Boissons » (Wello+)

Nouvelle section listant les `DrinkType` avec leur coefficient courant, ajustable par `Stepper`
borné (`coefficientRange`, pas 0.05) + « Réinitialiser » (actif si `isCustomized`). En gratuit,
la section se réduit à une ligne / `PremiumGateCard` menant au paywall. Gating via
`entitlements.isUnlocked(.customDrinks)`.

## HealthKit

À l'enregistrement d'une prise, on écrit `max(0, effectiveML)` comme « Eau » (`dietaryWater`) :
une boisson à effectif négatif ou nul n'écrit **rien**. La suppression est symétrique (même
quantité effective, même date). L'import des prises **externes** reste de l'eau brute (coeff
1.0), inchangé.

## Gestion d'erreur & cas limites

- Coefficient édité hors bornes → ramené dans `coefficientRange` par `resolveCoefficient`.
- Jour entièrement « négatif » (que de l'alcool) → `clampedDayTotal` borne le consommé à 0 ;
  l'objectif n'est évidemment pas atteint.
- `drinkType` inconnu (donnée corrompue / future valeur) → repli sur `water` à la lecture.

## Stratégie de test

- **Logique pure (`WelloKit`, `swift test`)** — nouvelle suite `Drink` :
  - `effectiveHydrationML` : eau = identité ; café 250×0.8 = 200 ; spiritueux 100×(-0.5) = -50.
  - `resolveCoefficient` : override respecté ; bornes `[-1.0 … 1.5]` appliquées ; défaut si nil.
  - `clampedDayTotal` : somme négative → 0 ; positive → inchangée.
  - `DrinkType` : `water` est le 1ᵉʳ cas ; chaque cas a un coefficient par défaut dans les bornes.
- **Type-check iOS hors Xcode** : les nouveaux fichiers (`DrinkCatalog`, feuille de saisie,
  section Profil) passent `swiftc -typecheck`. Les globs du `CLAUDE.md` couvrent déjà
  `Services/*.swift` et `Views/*.swift` → aucune modification du `CLAUDE.md`.
- **Previews** : feuille de saisie `free` vs `plus` (`MockStoreService` + `PreviewSupport`),
  section Boissons du Profil, `DayDetailView` avec boissons variées.
- **Migration (Xcode, manuel)** : un build sur une base existante doit ouvrir sans perte ; les
  anciennes prises restent `water`/1.0.

## Hors périmètre

- Création de boissons entièrement custom (nom/icône libres) — non retenu (YAGNI).
- Boutons rapides par boisson — la saisie typée passe par la feuille « Autre ».
- Coefficients validés médicalement / sourcés cliniquement — les valeurs sont des heuristiques
  éditables, présentées comme telles.
- Type HealthKit distinct par boisson (caféine, alcool) — on n'écrit que de l'« Eau » effective.
