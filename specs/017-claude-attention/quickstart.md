# Quickstart : valider « Claude attend une action »

## Prérequis

- Build Debug : `scripts/build-app.sh` puis lancer `NotchUsage.app`.
- Claude Code installé (`claude --version`) ; au moins une session de l'app Claude ou du terminal.
- Tests : `swift test` (core) ; `xcodebuild test -scheme NotchUsage` (app).

## 1. Core (TDD, sans l'app)

```bash
swift test --filter ClaudeHookEvent
swift test --filter ClaudeSessionTracker
swift test --filter ClaudeHooksInstaller
swift test --filter NotchSignalTests
```

Attendu : décodage des fixtures du spike ; transitions de la table de [data-model.md](data-model.md) ;
fusion/retrait identiques à l'octet sur les fixtures `settings-0.json`, `settings-1.json`,
`settings-8.json` ; île conforme au [contrat](contracts/attention.md) pour chaque ligne.

## 2. Démo (sans Claude Code)

Les états démo reçoivent un suffixe d'attention : `swift scripts/demo.swift <état> claude=<attente>`
avec `claude=approval | question | done | approval3 | off`, et `claude=arrival` pour le libellé.

| Commande | Attendu |
|---|---|
| `normal claude=approval snapshot` | jauge grise, main violette à droite |
| `normal claude=arrival snapshot` | main + « Approbation », capture dans les 4 s |
| `normal claude=approval3 snapshot` | main + « 3 » |
| `far claude=question snapshot` | jauge ambre, bulle violette (plus de « 2:05 ») |
| `imminent claude=approval tick snapshot` | jauge rouge qui bat, « 8′ », point violet sur la jauge |
| `blocked claude=done snapshot` | jauge pleine rouge, « ↻1:02 », point blanc |
| `normal claude=approval3 panel` | section « Claude Code », trois lignes triées |
| `normal claude=done` puis `click=…` sur l'île | la coche disparaît |

Pilule : `layout=pill` avant chaque état. Plein écran : ouvrir une app en plein écran avec
`claude=approval`, le point est violet.

## 3. Réel (hooks)

1. Réglages → « Follow Claude Code » : `~/.claude/settings.json` contient 7 groupes avec le chemin du
   script ; `diff` avec une copie faite avant : seules ces lignes diffèrent.
2. Dans une session Claude Code, demander une commande soumise à permission : l'île montre la main en
   moins d'une seconde ; accorder : elle disparaît en moins d'une seconde.
3. Demander une question (`AskUserQuestion`) : bulle ; répondre : disparaît.
4. Laisser une session finir un tour : coche ; clic sur l'île : disparaît.
5. Fermer le terminal d'une session en attente sans répondre : au survol suivant, la ligne a disparu.
6. Quitter l'app, provoquer une attente, relancer : l'attente apparaît au lancement.
7. Désactiver le réglage : `settings.json` identique à la copie d'avant l'étape 1.
8. Config illisible (ajouter une virgule) : le réglage reste off, un message dans les réglages, rien d'écrit.

## 4. Budgets et finitions

- `swift scripts/demo.swift normal claude=approval` puis 10 min : CPU < 1 %, empreinte ± 2 Mo de la 0.5.3
  (Moniteur d'activité).
- `scripts/check-localizations.sh` : 0 texte sans traduction.
- VoiceOver sur l'île avec deux sessions : annonce « 2 sessions Claude attendent : … ».
- Captures README : `docs/images/states.png` avec les états Claude ; planche
  `docs/design/claude-attention.png` citée.
