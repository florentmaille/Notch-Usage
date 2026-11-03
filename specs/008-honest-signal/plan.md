# Implementation Plan: Signal honnête

**Branch**: `008-honest-signal` (sur `006-imminence-pulse`) | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary

`HeadlinePicker` (core) remplace `HeadlineChoice` : gravité par limite (épuisement, palier de prévision, niveau de
seuil), la plus grave porte le signal. `NotificationGate` (core, pure) dédoublonne par limite, motif et période ;
`SignalNotifier` (app) poste les `UNUserNotification` d'après le signal courant. `AlertSettings.notifications`
(décodage tolérant). Le point plein écran suit le palier et `beat`. Réglages : section Notch retirée, section Alertes
réécrite. Ligne de prévision « (dernière heure) ».

## Technical Context

Swift 6 ; UserNotifications ajouté (framework système). Tests : `HeadlinePickerTests` (8), `NotificationGateTests` (3),
reducer et signal adaptés. Aucun timer, aucune requête.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Notifications locales ; aucun contenu secret | PASS |
| II. Sobriété | Décision à chaque `recompute`, déjà déclenché ; au plus une notification par période | PASS |
| III. Tests | Sélection et garde dans le core, testées ; l'envoi (UNUserNotificationCenter) reste dans l'app | PASS |
| IV. YAGNI | Un réglage retiré, un ajouté (interrupteur) ; pas de centre de notifications maison | PASS |

## Project Structure

```text
Sources/NotchUsageCore/Display/HeadlinePicker.swift      # remplace HeadlineChoice.swift
Sources/NotchUsageCore/Alerts/NotificationGate.swift
Sources/NotchUsageCore/Models/AlertSettings.swift         # notifications
Sources/NotchUsageCore/Display/DisplayStateReducer.swift  # alertSettings au lieu de choice
Tests/NotchUsageCoreTests/{HeadlinePickerTests,NotificationGateTests,DisplayStateReducerTests,NotchSignalTests}.swift
App/NotchUsage/Alerts/SignalNotifier.swift
App/NotchUsage/AppModel.swift                             # picker, notifier, setNotificationsEnabled
App/NotchUsage/Views/{SettingsView,AlertDotView,NotchRootView,ExpandedView,CompactView}.swift
App/NotchUsage/Resources/Localizable.xcstrings
```

## Research

- **R1 gravité** : échelle entière 0-5 plutôt qu'un ordre partiel ; `holdsUntilReset` vaut 0 même à 97 % (005 FR-007a). Le critique sans prévision vaut l'imminent (4) : même teinte, même urgence perçue.
- **R2 notification** : décision prise sur `NotchSignal` (contenu + palier) et non sur `AlertEvent` (seuils) : un seul sens, celui du liseré. Identifiant de requête horodaté ; la garde empêche les doublons, pas le centre.
- **R3 réglage** : `notifications` séparé de `enabled` (seuils) : désactiver les seuils ne doit pas couper les notifications de prévision.
