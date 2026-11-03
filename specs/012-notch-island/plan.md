# Implementation Plan: Île de chaque côté de l'encoche

**Branch**: `012-notch-island` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary

Le core ajoute `NotchSignal.island` (jauge ou glyphe à gauche, donnée facultative à droite, teinte), dérivé
dans `NotchSignal.make` à partir des mêmes entrées que la 005. `content`, `edge` et `pulse` restent pour les
notifications, le plein écran et le battement. L'app remplace le liseré par une île : le panneau replié prend
la largeur encoche + oreille gauche (52 pt) + oreille droite (52 pt si donnée), décalé pour que l'encoche
physique reste au centre ; la forme noire remplit le panneau ; la jauge (anneau) bat sur `beat`. Au survol,
bande et panneau comme avant.

## Technical Context

Swift 6, SwiftUI, AppKit. Tests : `NotchSignalTests` (île par état), `IslandFormatTests` (échéance h:mm / ′),
tests app adaptés. Aucun timer ni requête.

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Rien de nouveau | PASS |
| II. Sobriété | Rendu statique ; une animation au battement (006) et un fondu de 0,3 s au changement d'état | PASS |
| III. Tests | Contenu de l'île décidé dans le core, testé avant la vue | PASS |
| IV. YAGNI | Retrait du liseré, du cerne, du débord et du rétrécissement différé de 0,6 s | PASS |

## Research

- **R1 panneau asymétrique** : `apply(display, ears:)` reçoit les largeurs gauche et droite ; origine x = milieu de l'écran − encoche/2 − gauche. La zone de survol suit le cadre, donc les oreilles visibles seulement (FR-005).
- **R2 forme** : la forme noire remplit le cadre du panneau (arrondi bas de 12 pt replié) : plus de forme réduite, plus de contour extérieur.
- **R3 fondu** : quand le cadre rétrécit (oreille droite qui disparaît), le changement de cadre attend 0,3 s pour laisser le fondu jouer ; quand il grandit, immédiat.
- **R4 jauge** : anneau de 16 pt, trait de 3 pt, piste gris foncé ; teinte grise, ambre, orange, rouge ; halo (ombre) statique en imminent et épuisé, double battement sur `beat` comme la 006.
- **R5 format** : `IslandFormat.deadline(remaining:)` : ≥ 3600 s → « h:mm », sinon « N′ » (minutes entières, plancher à 0).
