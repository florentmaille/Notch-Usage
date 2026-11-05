# Contrat : hooks installés, script, fichier d'événements

## Entrées dans `~/.claude/settings.json`

Toutes avec un seul hook : `{"type": "command", "command": "<script>", "timeout": 5}` où `<script>` est
`~/Library/Application Support/NotchUsage/claude-hook.sh` (chemin absolu, c'est le marqueur de propriété).

| Événement | `matcher` | Rôle |
|---|---|---|
| `PermissionRequest` | (absent) | approbation, ou question si `tool_name` = `AskUserQuestion` |
| `PostToolUse` | (absent) | effacement de l'approbation accordée / de la question répondue |
| `PostToolUseFailure` | (absent) | effacement de l'approbation accordée mais échouée |
| `Stop` | (absent) | terminé |
| `UserPromptSubmit` | (absent) | effacement ; titre de session |
| `SessionEnd` | (absent) | retrait |
| `SessionStart` | (absent) | création (pid, dossier), sans attente |

Règles de fusion : ajout d'un groupe à la fin de la liste de chaque événement ; les groupes des autres
sont intacts, clés et ordre compris ; retrait des seuls groupes portant `<script>` ; clé d'événement
supprimée si vide ; les autres clés racine (`autoMode`, `model`, `theme`…) ne sont jamais touchées.
Écriture : relire, modifier, écrire dans un fichier temporaire du même dossier, `rename`. Encodage
`prettyPrinted`, `sortedKeys`, `withoutEscapingSlashes`, retour à la ligne final.

Statut : `absent` (aucun groupe), `installed` (les 7), `partial` (1 à 6), `unreadable` (JSON invalide),
`claudeMissing` (`~/.claude` absent).

## Script `claude-hook.sh`

```sh
#!/bin/sh
# Notch Usage (017) : relaie un événement de Claude Code à l'app. Une ligne JSON par événement.
# L'app ne garde que le type, la session, le dossier, le titre et l'outil ; le fichier est vidé à chaque lecture.
f="$HOME/Library/Application Support/NotchUsage/claude-events.jsonl"
umask 077
printf '{"ppid":%s,"ts":%s,"event":' "$PPID" "$(date +%s)" >> "$f" || true
tr -d '\n' >> "$f" || true
printf '}\n' >> "$f" || true
```

Contraintes : termine en < 50 ms ; ne sort rien sur stdout (Claude Code lirait une réponse JSON) ; code
de sortie 0 quoi qu'il arrive ; muet si le dossier n'existe plus. `tr -d '\n'` garde une ligne par
événement quel que soit le payload (Claude Code termine ou non par un retour à la ligne).

Note : trois écritures par événement ; une ligne peut donc être lue incomplète. Le lecteur
ne consomme une ligne qu'au `\n` final et garde le reste pour la lecture suivante.

## Fichier `claude-events.jsonl`

Une ligne par événement : `{"ppid": 9019, "ts": 1762360000, "event": {<payload du hook tel quel>}}`.
Droits 600. Tronqué par l'app (offset remis à 0) après consommation au-delà de 64 Ko et au lancement
après rattrapage ; jamais lu par autre chose.

## Payload utile (spike)

`event.hook_event_name`, `event.session_id`, `event.cwd`, `event.session_title` (desktop,
`UserPromptSubmit`), `event.tool_name` (`PermissionRequest`, `PostToolUse*`), `event.prompt_id`,
`event.permission_mode`. Le reste (`prompt`, `last_assistant_message`, `tool_input`, `transcript_path`,
`scratchpad_dir`) est ignoré.
