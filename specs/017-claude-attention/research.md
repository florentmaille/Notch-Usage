# Research : Claude attend une action

## R1 - Transport des événements

- **Decision** : hook `command` → `claude-hook.sh` → `cat >> claude-events.jsonl` dans le conteneur ; l'app
  surveille le fichier avec `DispatchSource.makeFileSystemObjectSource(.write | .extend)`.
- **Rationale** : zéro réseau (constitution I), zéro polling (II), fonctionne app fermée (les lignes
  s'accumulent, rattrapées au lancement), un seul `write` par événement donc pas de ligne coupée sous 4 Ko.
  Le spike a mesuré des payloads de 0,5 à 3 Ko.
- **Alternatives** : hook `http` vers un serveur local (c'est ce que fait l'app Claude ; un `NWListener`,
  un port à négocier, et rien quand l'app est fermée) ; notifications distribuées depuis le script (il
  faudrait un binaire, le script ne peut pas poster) ; XPC (sans intérêt pour un sens unique).

## R2 - Contenu du fichier et vie privée

- **Decision** : le script passe le JSON tel quel ; l'app ne décode que `hook_event_name`, `session_id`,
  `cwd`, `session_title`, `tool_name`, `permission_mode`, plus `pid` et `ppid` ajoutés par le script
  (`$PPID` est le processus `claude`). Le fichier est tronqué à chaque consommation au-delà de 64 Ko et
  au lancement après rattrapage.
- **Rationale** : filtrer dans le script demanderait un parseur JSON (`jq` n'est pas garanti) ; le
  texte des conversations (`prompt`, `last_assistant_message`, `tool_input`) ne reste donc sur disque que
  jusqu'à la prochaine consommation, dans le conteneur de l'app, en 600. Documenté dans le README.
- **Alternatives** : `python3 -c` dans le script (présent sur macOS, mais 50 ms de démarrage par événement
  et une dépendance de plus) ; un binaire compagnon (bundle, signature, chemin mouvant).

## R3 - Sources et classification (spike)

- **Decision** : `PermissionRequest` → `question` si `tool_name == "AskUserQuestion"`, sinon
  `approbation` ; `Stop` → `terminé` ; `UserPromptSubmit`, `PostToolUse`, `PostToolUseFailure`,
  `SessionEnd` → effacement ; `SessionStart` → création (sans attente). `Notification` et `PreToolUse`
  ne sont pas installés.
- **Rationale** : vérifié desktop et CLI ([spike-hooks.md](spike-hooks.md)). Une question passe par le
  système de permission ; `Notification` doublonne.

## R4 - Effacement

| État | Effacé par |
|---|---|
| approbation | `PostToolUse` / `PostToolUseFailure` (même `tool_name`), `UserPromptSubmit`, `Stop`, `SessionEnd` |
| question | `PostToolUse` AskUserQuestion, `UserPromptSubmit`, `SessionEnd` |
| terminé | `UserPromptSubmit`, `SessionEnd`, clic sur l'île (efface tous les « terminé ») |

`Stop` après une question en attente n'arrive pas (le tour continue) ; `Stop` après une approbation
refusée par Esc n'arrive pas non plus : couvert par `UserPromptSubmit`/`SessionEnd`/expiration (R7).

## R5 - Fusion dans `~/.claude/settings.json`

- **Decision** : `ClaudeHooksInstaller` travaille sur `[String: Any]` (JSONSerialization, ordre des clés
  non garanti → écriture `sortedKeys` + `prettyPrinted` + `withoutEscapingSlashes`). Chaque groupe
  installé porte `"hooks": [{"type": "command", "command": "<chemin du script>", "timeout": 5}]` ; le
  marqueur de propriété est le chemin du script (sous `Application Support/NotchUsage/`). `remove` retire
  les groupes dont un hook a ce chemin, et la clé d'événement si elle devient vide ; `status` compare
  l'ensemble attendu à l'ensemble présent. Écriture atomique : fichier temporaire à côté puis `rename`.
  JSON illisible → `.unreadable`, aucune écriture. Fichier absent mais `~/.claude` présent → créé avec
  seulement `hooks`.
- **Rationale** : préserve les entrées de l'utilisateur à l'identique (SC-003, testé sur fixtures à 0, 1
  et 8 hooks, dont les hooks `http` de l'app Claude). Le spike a montré qu'une autre session peut écrire
  le fichier entre-temps (`autoMode.allow`) : l'app **relit juste avant d'écrire** et n'écrit que la
  différence de ses propres entrées, jamais à partir d'une copie ancienne.
- **Alternatives** : `Codable` strict (perdrait les clés inconnues) ; édition textuelle (fragile).

## R6 - Application d'origine

- **Decision** : le script ajoute `"ppid": $PPID` (pid de `claude`). L'app remonte les parents avec
  `proc_pidinfo`/`sysctl KERN_PROC` jusqu'à un processus qui est une `NSRunningApplication`
  (`bundleIdentifier` non nul) : app Claude, Terminal, iTerm, VS Code… Mémorisé avec la session.
  Clic → `activate(options: [])`.
- **Rationale** : `transcript_path`, `scratchpad_dir` ne disent pas l'app ; `$PPID` est fiable (le hook est
  un enfant direct de `claude`). Le spike montre `claude` enfant de `disclaimer`, lui-même enfant de
  `Claude.app` : trois niveaux au plus.
- **Alternatives** : ouvrir le dossier dans le Finder (ne ramène pas la session) ; URL scheme de l'app
  Claude (non documenté).

## R7 - Vivacité et expiration

- **Decision** : `kill(pid, 0) == 0 || errno == EPERM` → vivant. Vérifié pour les sessions en attente au
  survol, à chaque événement reçu et au lancement ; jamais sur timer. Sans `pid` (ligne ancienne),
  expiration 8 h après le dernier événement.
- **Alternatives** : `SessionEnd` seul (manqué quand le terminal est fermé) ; `NSWorkspace`
  `didTerminateApplicationNotification` (ne voit que les apps, pas les `claude` du terminal).

## R8 - Nom affiché

- **Decision** : `session_title` s'il est connu (arrive avec `UserPromptSubmit` desktop, mémorisé par
  session), sinon `URL(fileURLWithPath: cwd).lastPathComponent`, sinon « Session » + 4 premiers caractères
  de l'identifiant. Clarification du 2026-11-05.

## R9 - Priorité face à la limite et rendu

- **Decision** : décidé dans `NotchSignal.make` à partir de `edge` (imminent ou épuisé → la limite garde la
  droite, badge violet au coin de la jauge ; sinon l'attention prend la droite). Glyphes SF Symbols :
  `hand.raised.fill`, `questionmark.bubble.fill`, `checkmark` ; teinte `#BF5AF2` (approbation, question),
  blanc (terminé). Libellé d'arrivée 4 s : « Approval », « Question », « Done » / « Approbation »,
  « Question », « Terminé ». Compteur `monospacedDigit`, 13 pt, à droite du glyphe dans la même oreille
  (52 pt suffisent pour glyphe + 1 chiffre ; à 10 et plus, « 9+ »).
- **Rationale** : la planche validée ; la jauge garde sa couleur pour ne pas perdre le palier.

## R10 - Libellé d'arrivée sans timer permanent

- **Decision** : `AppModel.arrivalTask` : un `Task.sleep(4 s)` lancé à chaque arrivée, annulé par la
  suivante, puis `recompute()`. La vue compare `now` à `attention.arrivedAt`. Reduce Motion : même
  durée, sans fondu.

## R11 - Notification optionnelle

- **Decision** : `SignalNotifier.notifyClaude(session:)` pour approbation et question seulement, une par
  événement (identifiant `session_id-prompt_id`), titre « Claude is waiting » / « Claude attend », corps
  « <nom> : approval needed » / « <nom> : attend une approbation ». Réglage `notifiesClaudeAttention`,
  défaut off, visible seulement quand « Follow Claude Code » est activé.
