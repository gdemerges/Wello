# Wello — Suivi d'hydratation (iOS)

App iOS personnelle, mono-utilisateur, 100 % locale. Calcule un objectif d'hydratation
quotidien personnalisé (poids, activité HealthKit, météo Open-Meteo, plancher médical) et
aide à le suivre.

## Arborescence

```
Wello/                          ← racine
├─ WelloKit/                    ← Swift Package : logique métier pure (testable en CLI)
├─ Wello/                       ← projet Xcode
│  ├─ Wello.xcodeproj
│  └─ Wello/                    ← sources de l'app (App, Models, Services, Views)
├─ docs/                        ← spec et plan d'implémentation
└─ README.md
```

## Lancement

1. Ouvrir `Wello/Wello.xcodeproj` dans Xcode 26+ (cible iOS 17+).
2. **Lier le package local** : File ▸ Add Package Dependencies ▸ Add Local ▸ choisir le dossier
   `WelloKit`, puis ajouter la bibliothèque `WelloKit` au target `Wello`.
3. Vérifier que les fichiers de `Wello/Wello/` (App, Models, Services, Views) appartiennent au
   target `Wello` (avec les groupes synchronisés Xcode 16+, ils sont pris en compte
   automatiquement ; sinon, *Add Files to "Wello"*).
4. Configurer les capabilities & l'Info.plist (voir ci-dessous).
5. Cmd+R sur un simulateur ou un device iOS 17+.

## Tests de la logique métier

La logique critique (`HydrationCalculator`, `résoudrePoids`) vit dans le package `WelloKit`
et se teste sans Xcode :

```bash
cd WelloKit && swift test
```

## Permissions

Activer la capability **HealthKit** sur le target (Signing & Capabilities ▸ + Capability ▸
HealthKit), et renseigner dans l'Info.plist du target :

- `NSHealthShareUsageDescription` — lecture des séances, de l'énergie active et du poids.
- `NSHealthUpdateUsageDescription` — écriture des prises d'eau dans Santé.app.
- `NSLocationWhenInUseUsageDescription` — localisation pour la météo locale.

Les notifications sont demandées à l'usage. **Tous les refus sont gérés** : l'app reste
pleinement utilisable en saisie manuelle (effort = 0, poids depuis le profil, météo = bonus 0,
pas de rappels).

## Logique de calcul

```
base          = poids (kg) × 35
activité      = min(énergie active kcal × 1, 1000)      // 1 ml/kcal (HealthKit), plafonné
météo         = min(max(0, ressentie°C − 27) × 50, 600) // ressentie = apparent temp, 0 si indispo
physiologique = base + activité + météo
total         = min(4000, max(plancher médical, physiologique))
```

Le plancher médical n'est jamais sous-estimé ; l'objectif affiché est plafonné à **4000 ml**
(sécurité anti-hyperhydratation).

Le bonus d'activité dérive de l'**énergie active brûlée** (kcal, HealthKit) plutôt que de la
seule durée : la perte sudorale à l'effort est proportionnelle à la chaleur métabolique
produite. Évaporer 1 mL de sueur dissipe ~0,58 kcal et l'essentiel de l'énergie d'exercice
devient chaleur → **~1 mL d'eau par kcal** (coefficient conservateur, plafonné à 1000 ml).

Le bonus météo s'appuie sur la **température ressentie** (apparent temperature d'Open-Meteo),
qui combine déjà chaleur, humidité, vent et rayonnement — un seul indicateur cohérent du stress
thermique. Montée linéaire de **50 mL par °C ressenti au-dessus de 27 °C** (zone de confort),
plafonnée à 600 mL. Un 30 °C sec (sueur qui s'évapore) et un 30 °C humide (qui ne s'évapore plus)
donnent ainsi des ressentis — et des besoins — très différents.

## Où ajuster le plancher médical

Onglet **Profil** ▸ section « Plancher médical » (1000–4000 ml). Valeur par défaut : 2500 ml.

## Architecture

- `WelloKit/` — logique pure testable (calcul d'objectif, fallback poids).
- `Wello/Wello/Models` — modèles SwiftData (`UserProfile`, `DailyGoal`, `HydrationLog`).
- `Wello/Wello/Services` — HealthKit, météo, localisation, notifications, `HydrationStore`.
- `Wello/Wello/Views` — écrans SwiftUI (Principal, Historique, Profil) + composants.

Pattern « MV » : pas de ViewModels ; les vues utilisent `@Query` SwiftData et un
`HydrationStore` `@Observable` injecté via l'environnement. Services derrière des protocoles
(mocks fournis pour les previews).

## Hors périmètre (Phase 1)

watchOS, Widget iOS, complication Watch — prévus en Phase 2. Le découpage services/calculateur
est conçu pour les accueillir sans refonte. Le partage de données app ↔ widget se fera via un
App Group (pas de CloudKit : l'app est volontairement locale et mono-appareil).
