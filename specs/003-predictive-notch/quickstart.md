# Quickstart: Encoche prédictive

## Contrôles automatiques

```bash
swift test --filter "Forecast|CompactStrip|UsageHistory|RelativeTimeFormatter"
scripts/check-localizations.sh .build/DerivedData
```

Attendu : tests verts ; 0 texte sans traduction française.

## Captures en mode démo (build Debug)

```bash
open -n .build/DerivedData/Build/Products/Debug/NotchUsage.app --args -AppleLanguages "(fr)"
```

Puis, pour chaque état `normal`, `pace`, `warning`, `critical`, `blocked`, `offline`, `reauth` :

```bash
swift scripts/demo.swift <état> snapshot
```

La capture est écrite dans `$TMPDIR/notchusage-snapshot.png`. Comparer à
[docs/design/notch-v8-d1.png](../../docs/design/notch-v8-d1.png). Refaire en anglais
(`-AppleLanguages "(en)"`) et en niveaux de gris (Réglages Système → Accessibilité → Affichage →
Filtres de couleur → Niveaux de gris).

## Scénarios manuels

| # | Étapes | Attendu |
|---|---|---|
| 1 | Démo `normal`, encoche repliée | ✓ 2 h 14 à gauche, 42 % à droite, pas de barre |
| 2 | Démo `warning` puis `critical` | Pastille orange 83 %, puis rouge 97 % ; gauche inchangée |
| 3 | Démo `blocked` | Pastille rouge « Bloqué », ↻ 1 h 02 rouge à gauche |
| 4 | Démo `pace` | ⌛ 1 h 10 orange, 55 % blanc sans pastille |
| 5 | Démo `offline` | Tout en gris, wifi barré, compte à rebours qui continue (attendre 1 min) |
| 6 | Démo `reauth`, cliquer « Connexion » | Pas de soulignement ; la reconnexion s'ouvre |
| 7 | Écran externe sans encoche (ou `NotchGeometry` en mode pilule) | « ✓ 2 h 14 · 42 % » sans troncature, aussi en anglais |
| 8 | Compte réel, lancer `claude` en continu 15 min | Après deux relevés espacés de 10 min, la gauche passe de ✓ au sablier si le rythme mène à 100 % avant le reset |
| 9 | Quitter puis relancer l'app | La prévision est disponible au premier relevé (historique conservé) |
| 10 | Déconnexion | `~/Library/Application Support/NotchUsage/history.json` supprimé |
| 11 | Panneau déplié avec démo `pace` | Ligne « À ce rythme : bloqué à … » sous Fenêtre de 5 h ; aucune ligne sous les limites hebdomadaires |
| 12 | VoiceOver, démo `pace` | Annonce de la limite terminée par « à ce rythme bloqué à … » |
| 13 | Budget : 10 min de journal `com.notchusage` | 3 relevés, aucune requête supplémentaire ; CPU < 1 % dans le Moniteur d'activité |
| 14 | Tous les états en niveaux de gris | Chaque état reste distinct par sa forme |

## Résultats (2026-11-02, build Debug, Mac en français)

| # | Résultat |
|---|---|
| 1 | ✅ « ✓ 2 h 14 » à gauche, « 42 % » à droite, plus de barre |
| 2 | ✅ Pastilles orange « 83 % » et rouge « 97 % », gauche inchangée (« ✓ 3 j 5 h » sur la limite hebdomadaire) |
| 3 | ✅ Pastille rouge « Bloqué », « ↻ 1 h 02 » rouge |
| 4 | ✅ « ⌛ 1 h 10 » orange, « 55 % » blanc ; la démo passe l'historique synthétique par le vrai calcul (régression) |
| 5 | ✅ Tout en gris, wifi barré, « 1 h 49 » |
| 6 | ✅ « Connexion » orange sans soulignement ; l'état réel a été vérifié avec le vrai compte plus tôt dans la session |
| 7 | ✅ Pilule (hook `layout=pill`) : « ✓ 2 h 14 · 42 % », « ⌛ 23:21 · [97 %] », « ↻ 1 h 02 · [Bloqué] », « 🔒 Connexion » ; idem en anglais, aucune troncature |
| 8 | ⏳ Compte réel : historique alimenté (9 relevés en 10 min), prévision « unavailable » tant que l'écart n'atteint pas 10 min ; à confirmer sur une session de travail |
| 9 | ✅ `history.json` (968 octets) relu au lancement |
| 10 | ✅ `wipe()` supprime le dossier entier, `history.json` compris (test `MemorySnapshotStore` et code de `FileSnapshotStore`) |
| 11 | ✅ « À ce rythme : bloqué à 23:40 » sous Fenêtre de 5 h, rien sous les limites hebdomadaires ; « At this pace: blocked at 23:41 » en anglais |
| 12 | ✅ Annonces vérifiées par les tests `CompactStripTests` (fr et en) ; VoiceOver non rejoué à la main |
| 13 | ✅ 3 relevés en 10 min (22:22, 22:25, 22:28), CPU 0,0 % sur 30 s au repos, empreinte 24,5 Mo en Debug |
| 14 | ✅ Montage converti en niveaux de gris : pastille, sablier, flèche, wifi barré et cadenas distinguent chaque état |

Non-régression (FR-020) : survol → panneau 440 × 264, clic sur la bande → épinglé, Échap → replié 364 × 38 ; langue
anglaise et française vérifiées sur tous les états.
