# Data Model : Écran sans encoche

Tous les types sont dans `NotchUsageCore`, purs, `Sendable`, `Equatable`. Rien n'est persisté sauf les deux réglages.

## ScreenDescriptor (entrée)

| Champ | Type | Source |
|---|---|---|
| `id` | `String` | `NSScreenNumber` |
| `width` | `CGFloat` | `frame.width` |
| `safeAreaTop` | `CGFloat` | `safeAreaInsets.top` |
| `auxLeftWidth`, `auxRightWidth` | `CGFloat?` | zones auxiliaires |
| `isMain` | `Bool` | porte la barre principale |

## ScreenRoles (sortie de `ScreenRoles.assign(_:)`)

| Champ | Type | Règle |
|---|---|---|
| `island` | `(id: String, layout: NotchLayout)?` | premier écran à encoche ; s'il y en a plusieurs, celui qui est principal (FR-001, FR-003) |
| `plain` | `[PlainScreen]` | écrans sans encoche, dans l'ordre reçu |
| `PlainScreen.id` | `String` | |
| `PlainScreen.capsuleEligible` | `Bool` | `width >= 1700` (FR-012, FR-016) |
| `hasPlainScreen` | `Bool` | `!plain.isEmpty` (visibilité de l'icône en automatique) |

Un écran est « à encoche » si `safeAreaTop > 0` et que les deux zones auxiliaires existent et laissent une largeur positive (règle actuelle de `NotchGeometry`).

## BarContent (dérivé de `NotchSignal` + `DisplayState`)

| Champ | Type | Règle |
|---|---|---|
| `gauge` | `Gauge?` | `nil` sans relevé (anneau vide) |
| `Gauge.fraction` | `Double` | utilisation de la limite portée, 0…1 |
| `Gauge.tint` | `calm \| far \| near \| imminent \| exhausted` | teinte de l'île (`Island.Tint`) |
| `Gauge.beats` | `Bool` | imminent ou épuisé (006) |
| `text` | `String?` | pourcentage au calme ; temps restant dès un palier (format de l'oreille droite) |
| `textEmphasis` | `none \| imminent` | rouge seulement à l'imminence (FR-005) |
| `attention` | `Attention?` | glyphe du cas le plus pressant, `count` si > 1, `arrivalWord` pendant 4 s |
| `attentionAsBadge` | `Bool` | `true` sous 30 min ou limite épuisée : Claude réduit à un point sur la jauge (017) |
| `accessibility` | `String` | `NotchSignal.accessibility` (FR-019) |

`BarContent.compact` : `gauge` seul, `text = nil`, `attention = nil` (FR-022).

## MenuBarIconMode (réglage persisté)

`automatic` (défaut) · `always` · `never`.

- `migrate(legacy: Bool?) -> MenuBarIconMode` : `true` → `always` ; `false` ou absent → `automatic`.
- `isVisible(roles: ScreenRoles) -> Bool` : `always` → vrai ; `never` → faux ; `automatic` → `roles.hasPlainScreen`.

## Réglage pastille

`showsCenterCapsule: Bool`, défaut `false` (FR-011).

## Transitions

| Événement | Effet |
|---|---|
| Changement de configuration d'écran | `ScreenRoles` recalculé → île créée ou fermée, pastilles créées ou fermées, visibilité de l'item, popover fermé |
| Changement d'écran de la fenêtre de l'item | item compact si cet écran porte l'île, enrichi sinon |
| `recompute()` | `BarContent` recalculé ; item et pastilles redessinés seulement s'il a changé |
| Écran de pastille en plein écran | pastille → point centré (ou rien au calme) |
