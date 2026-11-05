# Data model : Claude attend une action

## ClaudeHookEvent (core, `Decodable`)

Une ligne du fichier d'événements. Champs gardés ; tout autre champ est ignoré au décodage.

| Champ | Type | Source | Note |
|---|---|---|---|
| `kind` | enum `permissionRequest, postToolUse, postToolUseFailure, stop, userPromptSubmit, sessionStart, sessionEnd, other` | `hook_event_name` | `other` : ligne ignorée après décodage |
| `sessionID` | String | `session_id` | clé des sessions |
| `cwd` | String | `cwd` | nom de repli |
| `sessionTitle` | String? | `session_title` | desktop seulement, sur `userPromptSubmit` |
| `toolName` | String? | `tool_name` | `AskUserQuestion` = question |
| `promptID` | String? | `prompt_id` | identifiant de notification |
| `pid` | Int32? | `ppid` ajouté par le script | processus `claude` |
| `receivedAt` | Date | `ts` ajouté par le script (epoch s) ; à défaut, heure de lecture | « depuis » |

Validation : ligne vide, JSON invalide ou sans `session_id` → ignorée, comptée dans un journal.

## ClaudeSession (core)

| Champ | Type | Règle |
|---|---|---|
| `id` | String | `session_id` |
| `cwd` | String | dernier reçu |
| `title` | String? | dernier `session_title` non vide |
| `originPID` | Int32? | dernier `pid` |
| `originApp` | String? | bundle id résolu par l'app (R6), mémorisé |
| `waiting` | `Waiting?` | voir états |
| `lastEventAt` | Date | expiration 8 h |

`Waiting` : `kind` (`approval`, `question`, `done`), `since: Date`, `toolName: String?`, `promptID: String?`.

Nom affiché (`displayName`) : `title` → dernier composant de `cwd` → « Session » + préfixe de l'id (R8).

### Transitions

| Depuis | Événement | Vers |
|---|---|---|
| (absent) | tout événement | session créée, `waiting = nil` puis règle ci-dessous |
| any | `permissionRequest`, tool ≠ AskUserQuestion | `approval(since: now, toolName)` |
| any | `permissionRequest`, tool = AskUserQuestion | `question(since: now)` |
| any | `stop` | `done(since: now)` |
| `approval` | `postToolUse` / `postToolUseFailure` même `toolName` | `nil` |
| `question` | `postToolUse` AskUserQuestion | `nil` |
| any | `userPromptSubmit` | `nil` (+ titre mémorisé) |
| any | `sessionEnd` | session retirée |
| `done` | clic sur l'île | `nil` |
| any | processus mort (vérification) ou 8 h sans événement | session retirée |

Une arrivée pendant un libellé en cours remplace l'attente et relance `since`.

## ClaudeSessionTracker (core, valeur)

- `reduce(_ event:) -> Self` ; `apply(events:)`.
- `expire(now:, alive: (Int32) -> Bool) -> Self`.
- `clearDone() -> Self`.
- `waiting: [ClaudeSession]` triés : approbation, question, terminé ; puis `since` croissant.
- `attention(now:) -> NotchSignal.Attention?` : nil sans session en attente.

## NotchSignal.Attention (core)

| Champ | Type | Règle |
|---|---|---|
| `kind` | `approval, question, done` | le plus pressant parmi les sessions |
| `count` | Int | sessions en attente, toutes sortes |
| `arrivedAt` | Date | dernière arrivée ; la vue montre le mot si `now - arrivedAt < 4 s` |
| `tint` | `.claude` (violet) pour approval et question, `.plain` (blanc) pour done | |

Placement décidé par `NotchSignal.make` : `island.trailing = .attention(...)` ou `island.badge = tint`
(R9). `accessibility` préfixée par « N sessions Claude attendent : … ».

## ClaudeHooksInstaller (core, pur)

- `install(into: Data, scriptPath:) throws -> Data` ; `remove(from: Data, scriptPath:) throws -> Data` ;
  `status(of: Data, scriptPath:) -> Status` (`absent, installed, partial, unreadable`).
- Entrées installées : voir [contracts/hooks.md](contracts/hooks.md).

## Réglages (app, `UserDefaults`)

| Clé | Type | Défaut |
|---|---|---|
| `followsClaudeCode` | Bool | false |
| `notifiesClaudeAttention` | Bool | false |

## Fichiers (conteneur `~/Library/Application Support/NotchUsage/`)

| Fichier | Rôle | Droits |
|---|---|---|
| `claude-hook.sh` | script appelé par Claude Code | 700, réécrit à chaque activation |
| `claude-events.jsonl` | file d'événements, tronquée après consommation | 600 |
