# Thèmes & icônes (Wello+) — Design

**Statut :** validé, prêt pour implémentation.
**Date :** 2026-06-18.

## Problème

Le paywall (`PaywallView`) annonce déjà « **Thèmes et icônes** » comme bénéfice Wello+, et
`PremiumFeature.themes` existe dans l'enum — mais aucune implémentation : on vend une feature
absente. La palette `WelloTheme` est figée (couleurs `static let` codées en dur).

## Décision

Livrer un choix de **thèmes de couleur** (teinte d'accent + dégradé d'eau) commutables à chaud,
réservés à Wello+ sauf le thème par défaut, plus le **mécanisme d'icône alternative** par thème
(assets fournis en étape manuelle, comme les autres étapes Xcode).

- Seules les teintes **accent / accentDeep / waterTop / waterBottom** sont thématisées. Les
  neutres adaptatifs (`canvas`, `card`, `ink`, `inkSoft`) restent fixes : ils portent la
  lisibilité clair/sombre, pas l'identité.
- Le widget garde son `WidgetTheme` dédié (découplé par design) — **hors périmètre** (le widget
  premium fera l'objet d'un spec ultérieur).

## Périmètre

### Inclus
1. `AppTheme` (WelloKit, pur) : 4 thèmes, palette hex, libellé FR, gratuité, nom d'icône alt.
2. `WelloTheme` rétro-compatible : teintes thématisées calculées sur une palette `current`
   échangeable ; **aucun call-site existant modifié**.
3. `ThemeStore` (app, `@Observable`) : sélection persistée (UserDefaults), application palette +
   icône, garde anti-rétrogradation si le premium est perdu (remboursement).
4. Rebuild propre à la bascule via `.id(thème)` sur le `TabView`, sélection d'onglet préservée.
5. Sélecteur dans `ProfileView` ; thèmes premium verrouillés → `PaywallView`.
6. Tests WelloKit purs sur `AppTheme`.

### Exclu (YAGNI)
- Thématisation du widget / de l'écran verrouillé (spec premium widget ultérieur).
- Thèmes personnalisés (color picker libre) — set fixe et soigné suffit.
- Mode sombre custom par thème — on garde l'adaptatif système des neutres.

## Architecture

### 1. WelloKit — `Models/AppTheme.swift` (pur, testable CLI)

```swift
public struct ThemePalette: Sendable, Equatable {
    public let accent: UInt        // 0xRRGGBB
    public let accentDeep: UInt
    public let waterTop: UInt
    public let waterBottom: UInt
}

public enum AppTheme: String, Sendable, CaseIterable, Identifiable {
    case glacier        // défaut, gratuit (palette actuelle de l'app)
    case aurore         // corail chaud
    case menthe         // vert d'eau
    case crepuscule     // indigo / violet

    public var id: String { rawValue }
    public var label: String { ... }            // "Glacier", "Aurore", ...
    public var estGratuit: Bool { self == .glacier }
    public var palette: ThemePalette { ... }
    /// Asset d'icône alternative ; nil = icône primaire (glacier).
    public var alternateIconName: String? { ... }   // "AppIcon-Aurore", ...
}
```

Raw values **stables** (persistance). Palette glacier = couleurs actuelles de `WelloTheme`.

### 2. App — `WelloTheme` rétro-compatible (`Views/Theme.swift`)

Les 4 teintes thématisées passent de `static let` à `static var` calculées :
```swift
enum WelloTheme {
    /// Palette active, mutée par ThemeStore (jamais lue avant son init).
    static var current: AppTheme = .glacier
    static var accent: Color { Color(hex: current.palette.accent) }
    static var accentDeep: Color { Color(hex: current.palette.accentDeep) }
    static var waterTop: Color { Color(hex: current.palette.waterTop) }
    static var waterBottom: Color { Color(hex: current.palette.waterBottom) }
    // canvas/card/ink/inkSoft : inchangés (static let). Gradients : inchangés (computed).
}
```
Aucun fichier appelant n'est touché (toujours `WelloTheme.accent`).

### 3. App — `Services/ThemeStore.swift` (`@Observable`, calqué sur `DrinkCatalog`)

```swift
@MainActor @Observable
final class ThemeStore {
    private(set) var selected: AppTheme
    init(defaults:) { lit UserDefaults → AppTheme ; pose WelloTheme.current }
    func select(_ theme: AppTheme)              // pose current + persiste + applique l'icône
    func enforceEntitlement(unlocked: Bool)     // si thème premium actif sans droit → glacier
    private func appliquerIcône(_ name: String?) // setAlternateIconName si supportsAlternateIcons
}
```
La sélection d'un thème premium est **gatée à l'UI** (tap verrouillé → paywall) ;
`enforceEntitlement` couvre le cas remboursement (appelé quand le statut est résolu).

### 4. Câblage

- `WelloApp` : `@State theme = ThemeStore()` ; `.environment(theme)` ;
  `.task` existant résout l'entitlement → appelle `theme.enforceEntitlement(unlocked:)`.
- `RootView` : `@Environment(ThemeStore.self)`, `@State` de sélection d'onglet, `.id(theme.selected)`
  sur le `TabView` (la sélection d'onglet, stockée dans RootView, survit au rebuild).

### 5. UI — section « Thème » dans `ProfileView`

Grille de pastilles (cercle rempli de l'accent + libellé). Thème courant coché. Thème premium
non débloqué : cadenas → ouvre `PaywallView(bénéfice: "Choisis ton ambiance")`. `glacier`
toujours sélectionnable.

### 6. Tests (WelloKit)

- `AppTheme.allCases` = 4, raw values attendues (stables).
- Seul `glacier` est gratuit ; les 3 autres non.
- `alternateIconName == nil` **uniquement** pour `glacier`.
- Palettes toutes distinctes (pas de copier-coller).
- `glacier.palette` == couleurs actuelles (non-régression visuelle).

## Icônes alternatives (étape manuelle, hors CLI)

L'app utilise `GENERATE_INFOPLIST_FILE = YES` (pas d'Info.plist). Pour activer les icônes :
1. Ajouter 3 jeux d'icônes (1024² + tailles) nommés `AppIcon-Aurore/-Menthe/-Crepuscule`.
2. Déclarer `CFBundleIcons` → `CFBundleAlternateIcons` (clés `INFOPLIST_KEY_*` ou Info.plist).

Tant que les assets manquent, `setAlternateIconName` échoue silencieusement (try? ignoré) : les
**couleurs** fonctionnent immédiatement, l'icône s'activera une fois les assets ajoutés.

## Cas limites

- Premium perdu (remboursement) avec thème premium actif → `enforceEntitlement(false)` repasse
  en `glacier` (couleur + icône primaire).
- `supportsAlternateIcons == false` (rare) → on ne tente pas l'icône, la couleur s'applique.
- Persistance d'un raw value inconnu (downgrade futur) → repli `glacier`.

## Vérification

1. `cd WelloKit && swift test` → vert (suite `AppTheme` ajoutée).
2. Type-check iOS hors Xcode → 0 erreur.
3. Previews Xcode (manuel) : sélection d'un thème premium en gratuit → paywall ; en Wello+ →
   l'accent et le dégradé d'eau changent dans toute l'app ; relance → thème conservé.
