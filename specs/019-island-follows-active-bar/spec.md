# Feature 019 : l'île suit la barre active

**Date** : 2026-11-09 · **S'appuie sur** : [018](../018-no-notch-screen/spec.md) (barre active, pastille), 012 (île), 017 (Claude).
Demandée et validée à l'essai par Florent, sur la build Release locale (MacBook + Dell 1920 pt).

## Règles

| Situation | Île (écran à encoche) | Pastille (écran sans encoche) |
|---|---|---|
| MacBook seul | inchangée (012) | sans objet |
| Écran sans encoche branché, on travaille sur le Mac | jauge à gauche ; à droite, le **pourcentage** au calme, sinon l'échéance ou Claude (inchangés) | détail complet (jusqu'à la 0.6.2 : anneau seul) |
| Écran sans encoche branché, on travaille ailleurs | **comme sur le Mac** : jauge et pourcentage, échéance ou Claude (jusqu'à la 0.6.2 : effacée, l'encoche physique seule) | détail complet |
| Survol de l'encoche | l'île ne s'agrandit plus ; une **carte détachée** (380 pt, 6 pt sous l'encoche, quatre coins arrondis) porte le panneau | carte de la 018 |

- 2026-11-10, retour de Florent : la pastille et l'île restent affichées en entier quel que soit l'écran où l'on travaille (« on ne voit plus rien sur le Mac »). Seul l'item de barre de menus suit encore la barre active, qu'il lit sur sa propre fenêtre : le suivi des clics (`ActiveBarTracker`) disparaît.
- La barre active vient de la fenêtre de l'item de barre de menus (spike 018). Si l'icône est réglée sur « Jamais », une sonde de largeur nulle prend le relais dès qu'un écran sans encoche est branché.
- VoiceOver, palier, battement et notifications partent du signal avant adaptation : rien ne change pour eux.
- Mouvement d'un seul tenant, comme la pastille :
  - les oreilles s'étirent (0 ↔ 52 pt) en 0,3 s ;
  - le fond noir épouse l'île, pas la fenêtre ;
  - la fenêtre s'élargit avant l'animation et ne rétrécit qu'après.
- Ouverture au survol : seul le contenu de la carte s'anime ; l'alignement et le fond ne glissent pas.

## Code

- **Core** : `NotchSignal.adapted(to: ActiveBar?)`, `Island.Trailing.percent`, `Island.folded`. Tests dans `IslandActiveBarTests`.
- **App** :
  - `AppModel.recompute` adapte l'île à la barre active.
  - `CompactView` : oreilles à largeur animée.
  - `NotchRootView` : île toujours repliée, avec `NotchCardView`.
  - `NotchPanelController` : la carte vit dans sa propre fenêtre, et l'île plus la carte forment une seule zone de survol.
