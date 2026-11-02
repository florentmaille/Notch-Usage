# Quickstart: Interface en français

## Contrôles automatiques

```bash
swift test --filter RelativeTimeFormatter
scripts/check-localizations.sh
```

Attendu : tests verts ; le script affiche le nombre de textes et échoue si une traduction française manque.

## Lancer l'app en français sans changer la langue du Mac

```bash
open -n .build/DerivedData/Build/Products/Debug/NotchUsage.app --args -AppleLanguages "(fr)"
```

Pour revenir à l'anglais : relancer sans argument (ou `-AppleLanguages "(en)"`).

## Scénarios manuels

| # | Étapes | Attendu |
|---|---|---|
| 1 | App en français, compte connecté, survoler l'encoche | Libellés des limites, durées, jours et pied du panneau en français |
| 2 | App en anglais | Textes identiques à 0.1.0 |
| 3 | App en français, se déconnecter | Écran de connexion et note de risque en français |
| 4 | Réglages, coller une clé invalide | Message d'erreur en français |
| 5 | « Sign in with browser » | Titre de la fenêtre en français |
| 6 | VoiceOver, app en français | Chaque limite annoncée en français |
| 7 | Mode démo Debug `critical`, `reauth` | Encoche et bandeaux en français |
| 8 | Réglages → Langue → Français → Redémarrer (Mac en anglais) | App en français ; retour à « Système » → anglais |
