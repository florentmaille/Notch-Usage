# Implementation Plan: Claude attend une action

**Branch**: `017-claude-attention` | **Date**: 2026-11-05 | **Spec**: [spec.md](spec.md) | **Spike**: [spike-hooks.md](spike-hooks.md)

## Summary

Claude Code prévient par ses hooks ; l'app s'y abonne par un script qui ajoute une ligne JSON à un fichier
du conteneur, lu par un `DispatchSource` (aucun polling, aucun réseau). Le core (`NotchUsageCore`) porte
tout ce qui se décide : la **réduction** des événements en sessions suivies (`ClaudeSessionTracker`), la
**fusion** des entrées dans `settings.json` (`ClaudeHooksInstaller`, pur, testé sur fixtures), et le
**signal** ajouté à l'île (`NotchSignal.Attention`, règle de priorité face à la limite). L'app ajoute la
lecture du fichier, la vérification des processus, l'oreille droite et le point plein écran, la section
« Claude Code » du panneau et du menu, le réglage, la notification optionnelle.

## Technical Context

**Language/Version** : Swift 6, concurrence stricte. **Dependencies** : Foundation, SwiftUI, AppKit,
UserNotifications ; rien de nouveau (constitution IV). **Storage** : `~/Library/Application Support/NotchUsage/`
(`claude-events.jsonl`, `claude-hook.sh`), `UserDefaults` pour les deux réglages, lecture-écriture de
`~/.claude/settings.json`. **Testing** : Swift Testing dans `NotchUsageCoreTests` (TDD : réduction, fusion,
signal, format), `NotchUsageAppTests` pour les pièces de présentation ; fixtures JSON des événements et de
`settings.json`. **Target** : macOS 14+, app non sandboxée (entitlements vides, hardened runtime) : l'accès à
`~/.claude` et aux processus ne demande rien. **Performance** : zéro timer nouveau ; une lecture par
événement (quelques par minute au plus) ; vérification des processus seulement au survol, à l'événement et
au lancement. **Constraints** : CPU < 1 %, empreinte ± 2 Mo, aucun fondu en Reduce Motion, aucune écriture
dans `settings.json` sans geste de l'utilisateur. **Scope** : ~6 fichiers core, ~8 fichiers app, 2 réglages,
2 textes de notification, 1 planche.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Aucune connexion réseau. Le fichier d'événements ne garde que `session_id`, `cwd`, `session_title`, `tool_name`, horodatage ; `prompt`, `last_assistant_message` et `tool_input` sont **filtrés par le script** avant écriture (ils contiennent le texte des conversations). Rien ne quitte la machine. | PASS |
| II. Sobriété | `DispatchSource` sur le fichier (événementiel) ; aucun polling ; une relecture incrémentale par événement ; `kill(pid, 0)` pour les processus, pas de `ps`. Fondu 0,3 s et libellé 4 s par un `Task` annulable, rien en boucle. | PASS |
| III. Tests | Réduction, fusion/retrait, priorité, compteur, tri, noms, expiration : dans le core, sur fixtures, tests avant code. | PASS |
| IV. YAGNI | Pas de serveur HTTP, pas de XPC, pas de protocole de transport : un fichier append-only. Pas d'abstraction « autre agent ». Pas de ciblage de fenêtre (impossible depuis l'extérieur). | PASS |
| Entitlements | Inchangés (vides). | PASS |

Re-vérifié après la phase 1 : inchangé. Une écriture hors conteneur, `~/.claude/settings.json`, est
justifiée par le réglage explicite (FR-004) ; elle est atomique (fichier temporaire puis `rename`) et
jamais faite sur un JSON illisible.

## Research

Voir [research.md](research.md). Décisions : R1 transport par fichier + `DispatchSource` ; R2 le script
`sh` passe le JSON **tel quel** (pas de parseur JSON en shell, `jq` non garanti) et c'est l'app qui ne
garde que les champs utiles et tronque le fichier à chaque consommation, pour que le texte des
conversations ne persiste que quelques secondes ; R3 détection de la source par `PermissionRequest.tool_name` ; R4 effacement ; R5 fusion de `settings.json`
par marqueur ; R6 application d'origine par `$PPID` remonté jusqu'à une app ; R7 vivacité des sessions par
`kill(pid, 0)` ; R8 nom affiché ; R9 priorité face à la limite dans `NotchSignal`.

## Project Structure

### Documentation (this feature)

```text
specs/017-claude-attention/
├── plan.md, research.md, data-model.md, quickstart.md, spike-hooks.md
├── contracts/attention.md       # contenu de l'île et du panneau par état
├── contracts/hooks.md           # entrées installées, format du fichier d'événements, script
└── tasks.md                     # /speckit-tasks
```

### Source Code

```text
Sources/NotchUsageCore/
├── Claude/ClaudeHookEvent.swift        # décodage d'une ligne : type, session, cwd, titre, outil, pid, horodatage
├── Claude/ClaudeSessionTracker.swift   # état des sessions : reduce(event), expire(now, alive:), sorted
├── Claude/ClaudeHooksInstaller.swift   # install/remove/status sur un Data JSON de settings.json (pur)
├── Display/NotchSignal.swift           # + Attention (glyphe, compteur, teinte, badge), priorité, accessibilité
└── Display/AttentionFormat.swift       # nom affiché, « depuis », libellé d'arrivée

App/NotchUsage/
├── Claude/ClaudeEventsWatcher.swift    # DispatchSource sur claude-events.jsonl, lecture incrémentale, troncature
├── Claude/ClaudeHookScript.swift       # écrit claude-hook.sh dans le conteneur, chmod +x
├── Claude/ClaudeSettingsFile.swift     # lit/écrit ~/.claude/settings.json (atomique), appelle l'installer
├── Claude/ProcessLiveness.swift        # kill(pid, 0), app d'origine via NSRunningApplication / proc_pidpath
├── AppModel.swift                      # sessions, attention, réglages, clic, notification
├── Views/CompactView.swift             # oreille droite Claude : glyphe, libellé 4 s, compteur ; badge sur la jauge
├── Views/ExpandedView.swift            # section « Claude Code »
├── Views/SettingsView.swift            # « Follow Claude Code », « Notify me too »
├── Notch/StatusItemController.swift    # section du menu
└── Alerts/SignalNotifier.swift         # notification approbation / question

Tests/NotchUsageCoreTests/
├── ClaudeHookEventTests.swift, ClaudeSessionTrackerTests.swift, ClaudeHooksInstallerTests.swift
├── NotchSignalTests.swift (+ attention), AttentionFormatTests.swift
└── Fixtures/claude-hooks/*.json        # événements du spike, settings.json à 0, 1, 8 hooks
```

**Structure Decision** : même découpage que la 011 (`ClaudeCLI` dans le core, `ClaudeCodeRenewer` dans
l'app) : ce qui se décide est dans le core, ce qui touche le système dans l'app.

## Design

### Flux

1. Réglage activé → `ClaudeHookScript.ensure()` écrit le script, `ClaudeSettingsFile.install()` fusionne
   les entrées (R5), `ClaudeEventsWatcher.start()` ouvre le fichier.
2. Claude Code exécute le script → une ligne JSON ajoutée (append atomique sous 4 Ko, `O_APPEND`).
3. Le watcher lit les octets nouveaux depuis son offset, décode ligne à ligne (`ClaudeHookEvent`), ignore
   les lignes illisibles, tronque le fichier quand l'offset dépasse 64 Ko et qu'aucune écriture n'est en
   cours (le script écrit en une seule `write`), remet l'offset à 0.
4. `AppModel.sessions = tracker.reduce(events, now)` ; `recompute()` : `NotchSignal.make(display, now,
   attention: tracker.attention(now))` → île, panneau, menu, point plein écran, notification.
5. Libellé d'arrivée : `attention.arrival` porte l'événement et son heure ; la vue montre le mot tant que
   `now - arrival < 4 s` ; un `Task` de 4 s (annulé au suivant) force un `recompute()` pour le replier.
6. Au survol et à l'événement : `tracker.expire(now, alive: ProcessLiveness.isAlive)` retire les sessions
   mortes ; expiration 8 h sans processus connu.
7. Clic sur une ligne : `NSRunningApplication(processIdentifier: originPID)?.activate()` ; à défaut, par
   bundle id (`com.anthropic.claudefordesktop`, terminal).

### Priorité dans l'île (R9)

`NotchSignal.make` calcule l'île 012 puis applique l'attention : si `edge` est `.imminent` ou
`.exhausted`, l'île garde son trailing et reçoit `badge = attention.tint` ; sinon `trailing =
.attention(glyph, count, tint)` remplace l'échéance ou le libellé. `tint` de la jauge inchangée. Le point
plein écran lit `signal.fullscreenTint` : rouge si `edge` imminent ou épuisé, sinon la teinte de
l'attention, sinon celle du palier.

### Réglages

`followsClaudeCode` (défaut `false`), `notifiesClaudeAttention` (défaut `false`), `UserDefaults`.
Statut de l'abonnement recalculé au lancement et à l'ouverture des réglages :
`ClaudeHooksInstaller.status(settings)` → `.absent`, `.installed`, `.partial`, `.unreadable`,
`.claudeMissing` (dossier `~/.claude` absent).

## Complexity Tracking

Aucune violation. Le seul ajout structurel est le script shell dans le conteneur : nécessaire parce que
Claude Code n'exécute que des commandes et que le chemin du bundle change à chaque mise à jour.
