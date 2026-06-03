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

- `NSHealthShareUsageDescription` — lecture des séances et du poids.
- `NSHealthUpdateUsageDescription` — écriture des prises d'eau dans Santé.app.
- `NSLocationWhenInUseUsageDescription` — localisation pour la météo locale.

Les notifications sont demandées à l'usage. **Tous les refus sont gérés** : l'app reste
pleinement utilisable en saisie manuelle (effort = 0, poids depuis le profil, météo = bonus 0,
pas de rappels).

## Logique de calcul

```
base          = poids (kg) × 35
activité      = min(minutes d'effort × 11, 1000)        // plafonné
météo         = (temp > 28°C ? +300) + (humidité > 70% ? +200)   // 0 si météo indisponible
physiologique = base + activité + météo
total         = min(4000, max(plancher médical, physiologique))
```

Le plancher médical n'est jamais sous-estimé ; l'objectif affiché est plafonné à **4000 ml**
(sécurité anti-hyperhydratation).

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
