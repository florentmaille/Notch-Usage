# Spike : les hooks de Claude Code depuis l'app desktop et le CLI

**Date** : 2026-11-05 · **Claude Code** : CLI 2.1.316, app desktop 2.1.317 · **Durée** : 25 min

**Question** (spec FR-016) : les événements de permission, de question et de fin de tour sont-ils émis par
les sessions de l'app Claude (Code tab) comme par le CLI, et avec quelles données ?

**Méthode** : hooks `command` temporaires dans `~/.claude/settings.json` (un `cat >> fichier` pour
PermissionRequest, Notification, PreToolUse et PostToolUse sur AskUserQuestion, Stop, UserPromptSubmit,
SessionStart, SessionEnd), ajoutés sans redémarrer ; puis une question posée depuis une session desktop en
mode auto, une session desktop tierce qui a continué de travailler, `claude -p`, et deux sessions CLI
interactives en mode default (commande Bash soumise à permission, AskUserQuestion). Hooks retirés ensuite,
configuration vérifiée identique à l'octet près.

## Résultats

| Événement | Desktop, mode auto | CLI interactif, mode default | CLI `-p` | Données utiles |
|---|---|---|---|---|
| `PermissionRequest` | oui (AskUserQuestion) | oui (Bash, AskUserQuestion) | n/a | `tool_name`, `tool_input`, `permission_mode` |
| `Notification` `permission_prompt` | oui | oui | n/a | `message` ; doublon de PermissionRequest |
| `PreToolUse` AskUserQuestion | oui | oui | n/a | `tool_input.questions` |
| `PostToolUse` AskUserQuestion | oui, après la réponse | non observé (question annulée par Esc) | n/a | |
| `Stop` | oui, à chaque fin de tour | non après une interruption par Esc | oui | `last_assistant_message`, `permission_mode` |
| `UserPromptSubmit` | oui, y compris la réponse à une question | oui | oui | `prompt`, **`session_title`** (desktop) |
| `SessionStart` / `SessionEnd` | SessionEnd non observé (sessions encore ouvertes) | oui / oui | oui / oui | |
| `Notification` `idle_prompt` | non observé | non observé en 80 s sur une demande de permission | n/a | non vérifié |

Dans tous les cas : `session_id`, `cwd`, `transcript_path`, `scratchpad_dir`, `prompt_id`.

## Conclusions pour le plan

1. **Les sessions desktop émettent les hooks** de `settings.json`, et **à chaud** : une entrée ajoutée a
   été exécutée par une session ouverte depuis plus d'une heure, sans redémarrage. Le réglage « Suivre
   Claude Code » prend donc effet immédiatement (US4, scénario 2 confirmé).
2. **Une question passe par le système de permission** : `PermissionRequest` avec `tool_name` =
   `AskUserQuestion`. Source unique pour « approbation » et « question » : `PermissionRequest`, le
   `tool_name` distingue les deux. `PreToolUse` et `Notification` sont redondants.
3. **Fin de tour** : `Stop`. Il ne vient pas après une interruption (Esc) : l'attente s'efface alors au
   `UserPromptSubmit` suivant ou au `SessionEnd`, ce que la spec prévoit déjà.
4. **Effacement d'une approbation** : `PostToolUse` ou `PostToolUseFailure` du même outil (accordée),
   `UserPromptSubmit` (refusée avec un message, ou prompt suivant), `Stop` (refusée sans message, le tour
   finit), `SessionEnd`. Effacement d'une question : `PostToolUse` AskUserQuestion, puis
   `UserPromptSubmit` porte la réponse.
5. **Nom affiché** : `session_title` arrive avec `UserPromptSubmit` des sessions desktop ; absent en CLI.
   Choix de Florent : titre quand il existe, sinon dernier composant de `cwd`.
6. **Mode auto** : les sessions de Florent tournent en mode auto, où les demandes de permission sont rares
   (classificateur) ; les cas courants sont la question et la fin de tour. Le rendu ne change pas.
7. **Application d'origine** : à déterminer par le processus parent du hook (`$PPID` → app Claude ou
   terminal) ; à confirmer en implémentation.
8. Les hooks `http` de l'app desktop (port 19847) échouent en `ECONNREFUSED` depuis le CLI quand l'app
   n'écoute pas : sans effet sur les sessions, mais à garder en tête pour ne pas être pris pour un bug de
   l'app.

## Entrées à installer (US4)

`PermissionRequest`, `PostToolUse` et `PostToolUseFailure` (matcher `AskUserQuestion|Bash|Edit|Write|…`,
ou sans matcher), `Stop`, `UserPromptSubmit`, `SessionEnd` ; `SessionStart` facultatif (titre
inconnu à ce stade). Pas de `Notification`.
