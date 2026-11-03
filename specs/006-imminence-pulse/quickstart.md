# Quickstart : valider le battement d'imminence

## Prérequis

- Build Debug lancée (`xcodebuild -scheme NotchUsage -configuration Debug -derivedDataPath .build/DerivedData build`, puis `open` de l'app).
- `swift test` vert (NotchSignalTests avec les cas de rythme).

## Scénarios

| # | Commande ou geste | Attendu | Couvre |
|---|---|---|---|
| 1 | `swift scripts/demo.swift imminent25`, observer 3 min | Liseré rouge + halo ; aucun battement au premier tick, puis 1 par minute (± 5 s) : 3 battements en ~3 min 30 | US1 sc. 1, SC-001 |
| 2 | `swift scripts/demo.swift imminent`, observer 3 min | 1 battement toutes les 30 s (± 5 s) : 6 en ~3 min 30 | US1 sc. 2, SC-001 |
| 3 | `imminent snapshot` puis `tick snapshot` | Deux captures de mêmes dimensions ; seule la densité du halo diffère ; trait et teinte identiques (comparer les pixels du trait) | FR-003, SC-003 |
| 4 | `far`, `near`, `blocked`, `critical`, `warning` : 3 min chacun (ou `tick` × 6) | Aucun mouvement | US1 sc. 4 à 6, SC-002 |
| 5 | `imminent hover=1`, puis `tick` × 4 | Bande affichée, aucun battement ; `hover=0`, puis `tick` × 2 : battement au 2e tick | US1 sc. 7 |
| 6 | `imminent` + clic (épinglé), `tick` × 4 | Aucun battement ; désépingler : reprise au tick suivant | US1 sc. 7 |
| 7 | Réglages système → Réduire les animations, `imminent`, `tick` × 4 | Liseré + halo présents, immobiles | US1 sc. 8, FR-006 |
| 8 | `layout=pill`, `imminent`, `tick` × 4 | Pilule : halo qui respire au même rythme | US1 sc. 9, FR-007 |
| 9 | VoiceOver sur l'encoche en `imminent` | Même annonce qu'en 0.4.0 | US1 sc. 10, SC-006 |
| 10 | `imminent25` puis `imminent` (passage 25 → 8 min) | Rythme passe à 30 s au tick suivant, sans autre changement | US1 sc. 3 |
| 11 | `scripts/check-localizations.sh .build/DerivedData` | 87 textes, 0 sans traduction (aucun texte nouveau) | FR-010 |
| 12 | Instruments ou `ps`, 10 min en `imminent` | CPU < 1 %, empreinte à ± 1 Mo de la 0.4.0 | SC-005 |
| 13 | Compteur de requêtes (log) sur 10 min | Identique à la 0.4.0 | SC-005 |
| 14 | Depuis le centre de l'écran, `imminent`, sans regarder l'encoche | Le mouvement est remarqué (3 essais sur 3) | SC-004 |
| 15 | Build Release : `strings NotchUsage | grep -c com.notchusage.debug` | 0 (hook `tick` absent) | constitution |

## Résultats (2026-11-03, build Debug)

| # | Résultat | Détail |
|---|---|---|
| 1 | ✅ (par `tick`) | `imminent25` : `tick snapshot` × 2 → un battement sur les deux ticks (un tick sur deux) ; observation réelle de 3 min non rejouée |
| 2 | ✅ (par `tick`) | `imminent` : chaque `tick` bat ; observation réelle de 3 min non rejouée |
| 3 | ✅ | Captures 494 × 104 px toutes deux ; trait (247,76) r241 g108 b87 au repos, r244 g164 b154 à mi-battement (éclairci, même épaisseur) ; halo (247,90) alpha 48 au repos, modifié pendant le battement, 48 après 1 s |
| 4 | ✅ | `blocked` : `tick` ne change pas le halo (alpha 48 → 48) ; `near`, `far` : aucun halo ; `critical` (orange) et `warning` (ambre) : aucun halo, `pulse == .none` en core |
| 5 | ✅ | `imminent hover=1 tick` : bande + panneau, aucun halo ; `pulse == .none` (core) |
| 6 | ✅ (core) | Épinglé → `band` → `pulse == .none` ; reprise non rejouée à la souris |
| 7 | ⚠️ non rejoué | `reduceMotion` → ombre fixe à 0,6 sans `phaseAnimator` (code) |
| 8 | ✅ (par construction) | Même `NotchShape` et même modificateur en pilule ; non capturé |
| 9 | ⚠️ non rejoué | Annonce inchangée : `accessibility` non touché |
| 10 | ✅ (core) | `rhythm` : 25 min → `everyMinute`, 8 min → `everyHalfMinute` ; changement appliqué au tick suivant par `tick()` |
| 11 | ✅ | 87 textes, 0 sans traduction |
| 12 | ✅ | 60 s en `imminent` : 0,08 s CPU (0,13 %) ; empreinte 24,5 Mo (0.4.0 : 23,6 Mo en Debug) |
| 13 | ✅ (par construction) | Aucune requête ni timer ajoutés ; `tick()` remplace le corps du `tickTask` existant |
| 14 | ⚠️ à l'œil | À juger par l'utilisateur sur son écran |
| 15 | ✅ | Archive Release : 0 chaîne `com.notchusage.debug` |

Écart : le premier battement après l'entrée en état imminent arrive au tick suivant quand l'entrée vient d'un
relevé ou de la démo (pas d'un tick) ; R3 ne retient que le cas où le tick lui-même fait entrer l'état.
