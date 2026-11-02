# Data Model: Limites d'abonnement Claude dans l'encoche

**Feature**: `001-claude-usage-notch` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)

Toutes les entités vivent dans le module `NotchUsageCore` (sans SwiftUI ni AppKit) et sont
des `struct` `Sendable`, `Equatable`, `Codable` quand elles sont persistées. Les secrets ne
sont jamais dans ces structures : ils restent dans le Trousseau, référencés par identifiant.

## Entités

### Account

Le compte Claude connecté. Un seul à la fois.

| Champ | Type | Règles |
|---|---|---|
| `connectionMethod` | `enum ConnectionMethod { claudeCode, browser }` | Fixé à la connexion, change seulement à la reconnexion |
| `subscriptionType` | `enum SubscriptionType { pro, max, unsupported }` | `unsupported` → aucune jauge, message « abonnement non pris en charge » |
| `status` | `enum AccountStatus { connected, expired, disconnected }` | Voir transitions ci-dessous |
| `credentialRef` | `String` | Identifiant de l'entrée Trousseau de l'app. Jamais la valeur du secret |
| `connectedAt` | `Date` | Information uniquement |

**Transitions**

```text
disconnected --(connexion réussie)--> connected
connected    --(401/403 ou refresh impossible)--> expired
expired      --(reconnexion réussie)--> connected
connected | expired --(déconnexion)--> disconnected   (supprime credentialRef + cache)
```

### UsageLimit

Une limite exposée par le service pour ce compte.

| Champ | Type | Règles |
|---|---|---|
| `id` | `String` | Clé du service (`five_hour`, `seven_day`, `seven_day_<model>`...). Unique dans un relevé |
| `kind` | `enum LimitKind { rollingFiveHour, weeklyAll, weeklyModel }` | Dérivé de `id` ; une clé inconnue de forme `seven_day_*` → `weeklyModel` |
| `modelName` | `String?` | Nom tel que fourni par le service, non codé en dur. `nil` sauf `weeklyModel` |
| `label` | `String` | Libellé d'affichage, dérivé de `kind` + `modelName`, localisable |
| `utilization` | `Double` | 0...100, borné. Hors bornes → borné et journalisé |
| `resetsAt` | `Date?` | `nil` si le service ne la fournit pas ; l'UI affiche alors « — » |

**Règles**
- Une limite dont le service ne renvoie rien n'existe pas dans le relevé (pas de « 0 % »,
  FR US1 scénario 6).
- `isBlocked` = `utilization >= 100`.

### UsageSnapshot

L'ensemble des limites obtenues à un instant donné. Dernier relevé valide persisté en local.

| Champ | Type | Règles |
|---|---|---|
| `limits` | `[UsageLimit]` | Ordre d'affichage : `rollingFiveHour`, `weeklyAll`, puis `weeklyModel` par `modelName` |
| `fetchedAt` | `Date` | Horodatage de la réponse |
| `freshness(now:)` | calculé → `enum Freshness { fresh, aging, stale }` | `fresh` < 2 cycles de rafraîchissement ; `aging` ≥ 2 cycles (affiche l'ancienneté, FR-010) ; `stale` ≥ 30 min (marqué périmé, cas limite hors ligne) |
| `mostConstraining` | calculé → `UsageLimit?` | Plus haute `utilization` ; égalité → ordre d'affichage |

### FetchState

État courant du rafraîchissement, non persisté.

| Valeur | Signification | UI |
|---|---|---|
| `idle(lastSnapshot)` | Dernier relevé disponible | Valeurs + ancienneté si `aging`/`stale` |
| `loading(previous)` | Requête en cours | Valeurs précédentes conservées, pas de clignotement |
| `failed(reason, previous)` | Erreur réseau, 5xx, réponse malformée | « données indisponibles » + dernières valeurs valides |
| `reauthRequired` | 401/403, refresh impossible | « reconnexion requise », aucune valeur chiffrée |
| `unsupported` | Compte sans limites exposées | « abonnement non pris en charge » |

### AlertSettings

| Champ | Type | Défaut | Règles |
|---|---|---|---|
| `enabled` | `Bool` | `true` | |
| `warningThreshold` | `Int` | 80 | 1...99, strictement < `criticalThreshold` |
| `criticalThreshold` | `Int` | 95 | 2...100, strictement > `warningThreshold` |

### AlertLedger

Suit les seuils déjà signalés, pour garantir au plus une alerte par seuil, par limite et par
période (FR-019).

| Champ | Type | Règles |
|---|---|---|
| `entries` | `[String: AlertEntry]` | Clé = `UsageLimit.id` |
| `AlertEntry.periodKey` | `Date` (= `resetsAt`) | Si `resetsAt` change → nouvelle période, entrée réinitialisée |
| `AlertEntry.firedLevels` | `Set<AlertLevel>` | `warning`, `critical` |

**Algorithme d'évaluation** (pure, testable) :

```text
evaluate(snapshot, settings, ledger) -> (newLedger, [AlertEvent])
  pour chaque limit :
    entry = ledger[limit.id] ; si entry.periodKey != limit.resetsAt → entry vide
    si enabled et utilization >= critical et .critical ∉ fired → émettre critical
    sinon si enabled et utilization >= warning et .warning ∉ fired → émettre warning
    ajouter le niveau émis à fired
```

L'état visuel de l'encoche est dérivé, pas stocké : `max(level où utilization >= seuil)`.
L'oscillation autour d'un seuil ne ré-émet rien, car le niveau reste dans `firedLevels`.

### RefreshSettings

| Champ | Type | Défaut | Règles |
|---|---|---|---|
| `interval` | `Duration` | 60 s | 30 s ... 15 min (FR-007) |
| `launchAtLogin` | `Bool` | `false` | FR-020 |

### DisplayState

Dérivé en continu, non persisté. Pilote la vue.

| Champ | Valeurs |
|---|---|
| `mode` | `notch` (écran principal avec encoche) / `pill` (sans encoche) |
| `panel` | `collapsed` / `hoverOpen` / `pinned` |
| `fullscreenHidden` | `Bool` : une app est en plein écran et le pointeur n'est pas en haut |
| `alertLevel` | `none` / `warning` / `critical`, dérivé de `UsageSnapshot` + `AlertSettings` |

## Persistance locale

| Donnée | Emplacement | Effacée à la déconnexion |
|---|---|---|
| Jeton / cookie de session | Trousseau (SecItem, `kSecClassGenericPassword`, service `com.notchusage.credentials`) | Oui |
| Dernier `UsageSnapshot` | `Application Support/NotchUsage/snapshot.json` | Oui |
| `AlertLedger` | `Application Support/NotchUsage/alerts.json` | Oui |
| `AlertSettings`, `RefreshSettings` | `UserDefaults` | Non |
| `Account` (sans secret) | `UserDefaults` | Oui |

## Relations

```text
Account 1 ──── 0..1 UsageSnapshot ──── * UsageLimit
AlertSettings + UsageSnapshot ──(evaluate)──> AlertLedger, [AlertEvent]
UsageSnapshot + AlertSettings + écran ──> DisplayState
```
