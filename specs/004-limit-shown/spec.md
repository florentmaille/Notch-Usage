# Feature Specification: Limite affichée (rétroactive)

**Feature Branch**: `004-limit-shown` (fusionnée le 2026-11-03, PR 11) | **Status**: Remplacée par la [008](../008-honest-signal/spec.md)

Écrite après coup (009) pour rétablir la chaîne des références « règle 004 » des specs 005 et 006.

## Ce qui a été livré

- Réglage « Limite affichée » (Automatique, ou une limite épinglée) dans Réglages → Encoche, enregistré sous `headlineLimit`.
- Automatique : la limite épuisée qui bloque tout (5 h ou hebdo toutes limites), sinon celle dont le blocage est prévu le plus tôt, sinon la fenêtre de 5 h, sinon la plus utilisée. Une limite de modèle épuisée ne prenait pas le dessus.
- Le niveau d'alerte, la pastille et le point plein écran suivaient la limite affichée, pas la plus haute de toutes.

## Pourquoi elle a été remplacée

Épingler une limite rendait la seule prévision disponible (5 h) muette dans l'encoche, et en Automatique une hebdo à 97 % restait silencieuse tant que la 5 h tenait. La 008 retient une règle unique, « la plus menaçante de toutes », et retire le réglage ; une valeur enregistrée est ignorée.
