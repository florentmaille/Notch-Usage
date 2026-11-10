# Contrat : hooks installés, script, fichier d'événements

## Entrées dans `~/.claude/settings.json`

Toutes avec un seul hook : `{"type": "command", "command": "[ ! -x '<script>' ] || exec '<script>'", "timeout": 5}`
où `<script>` est `~/Library/Application Support/NotchUsage/claude-hook.sh` (chemin absolu). Cette commande est
le marqueur de propriété. Claude Code la passe à un shell (`-c`) :

- le chemin est entre apostrophes : il contient une espace ;
- script absent (app désinstallée, entrées restées) : rien ne s'exécute, code 0, aucune erreur de hook ;
- `exec` remplace le shell de la commande : le `$PPID` du script est le processus qui a lancé le hook, pas un
  shell déjà terminé quand l'app vérifie que la session vit encore (vérifié avec sh, bash, zsh et dash).

Les versions 0.5.4 à 0.6.1 écrivaient le chemin brut : le shell le coupait à l'espace et le script ne tournait
jamais (code 127 à chaque événement). Ces entrées sont aussi reconnues comme les nôtres : remplacées à
l'installation et au lancement de l'app quand le réglage est actif, retirées à la désactivation. Tant qu'il en
reste une, le statut n'est pas « installé ».

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
sont intacts, clés et ordre compris ; retrait des seuls hooks portant notre commande, le groupe disparaît
s'il est vide et garde les hooks de l'utilisateur sinon ; clé d'événement supprimée si vide ; les autres clés
racine (`autoMode`, `model`, `theme`…) ne sont jamais touchées. Une section `hooks` ou une liste d'événement de
forme inattendue n'est jamais écrasée : l'installation échoue, le retrait laisse le fichier tel quel.
Écriture : relire, modifier, écrire dans un fichier temporaire du dossier de la cible (lien symbolique résolu,
le lien reste en place), `rename`. Encodage
`prettyPrinted`, `sortedKeys`, `withoutEscapingSlashes`, retour à la ligne final.

Statut : `absent` (aucun groupe), `installed` (les 7), `partial` (1 à 6), `unreadable` (JSON invalide),
`claudeMissing` (`~/.claude` absent).

## Script `claude-hook.sh`

```sh
#!/bin/sh
# Notch Usage (017) : relaie un événement de Claude Code à l'app, une ligne JSON par événement.
# L'app ne garde que le type, la session, le dossier, le titre et l'outil ; le fichier est vidé à chaque lecture.
f='<dossier de l'app>/claude-events.jsonl'
umask 077
[ -d "${f%/*}" ] || exit 0
/usr/bin/pgrep -a -x 'NotchUsage' >/dev/null 2>&1 || exit 0
if [ "$1" != locked ] && [ -x /usr/bin/lockf ]; then
  /usr/bin/lockf -k -s -t 2 "$f.lock" "$0" locked "$PPID" 2>/dev/null
  exit 0
fi
[ "$1" = locked ] && p=$2 || p=$PPID
[ "$(/usr/bin/stat -f %z "$f" 2>/dev/null || echo 0)" -gt 1048576 ] && : > "$f" 2>/dev/null
printf '{"ppid":%s,"ts":%s,"event":' "$p" "$(date +%s)" >> "$f" 2>/dev/null || exit 0
tr -d '\n' >> "$f" 2>/dev/null || true
printf '}\n' >> "$f" 2>/dev/null || true
exit 0
```

Contraintes : termine en < 50 ms ; ne sort rien sur stdout (Claude Code lirait une réponse JSON) ; code
de sortie 0 quoi qu'il arrive ; muet si le dossier n'existe plus. `tr -d '\n'` garde une ligne par
événement quel que soit le payload (Claude Code termine ou non par un retour à la ligne).

Verrou : le script se relance sous `lockf` (verrou `claude-events.jsonl.lock`, libéré par le noyau si le hook
est tué). Deux hooks simultanés, sessions ou outils en parallèle, n'entremêlent donc plus leurs trois
écritures. Le pid du lanceur passe en argument : le parent du script relancé est `lockf`. Sans `lockf`,
l'écriture se fait sans verrou.

App fermée : le script sort sans rien écrire (`pgrep -a -x NotchUsage` ; `-a` compte aussi les ancêtres du script). Le payload porte le texte des
conversations ; il ne doit pas rester sur disque jusqu'au prochain lancement. Les événements émis app fermée
sont perdus : une session qui se met en attente pendant ce temps n'apparaît qu'à son événement suivant. L'app
vide aussi le fichier à l'arrêt du lecteur.

Plafond : passé 1 Mo, le fichier repart de zéro avant l'écriture. Garde-fou pour une app en marche qui ne le
vide plus (bloquée).

Le lecteur (hors verrou) peut lire une ligne incomplète : il ne consomme une ligne qu'au `\n` final et garde
le reste pour la lecture suivante.

## Fichier `claude-events.jsonl`

Une ligne par événement : `{"ppid": 9019, "ts": 1762360000, "event": {<payload du hook tel quel>}}`.
Droits 600. Tronqué par l'app (offset remis à 0) après consommation au-delà de 64 Ko et au lancement
après rattrapage ; jamais lu par autre chose.

## Fichier `claude-sessions.json`

Sessions suivies, écrites par l'app à chaque changement (droits 600) : identifiant de session, dossier, titre, pid,
application d'origine, attente en cours (nature, depuis quand, outil). Jamais de texte de conversation. Relu au
lancement, pour qu'une attente déjà lue avant un redémarrage de l'app réapparaisse sans attendre le prochain
événement de la session ; les sessions dont le processus a disparu, ou antérieures au démarrage du Mac (pid
réattribuable), sont écartées. Supprimé dès que plus rien n'est suivi, et quand le réglage est désactivé.

## Payload utile (spike)

`event.hook_event_name`, `event.session_id`, `event.cwd`, `event.session_title` (desktop,
`UserPromptSubmit`), `event.tool_name` (`PermissionRequest`, `PostToolUse*`), `event.prompt_id`,
`event.permission_mode`. Le reste (`prompt`, `last_assistant_message`, `tool_input`, `transcript_path`,
`scratchpad_dir`) est ignoré.
