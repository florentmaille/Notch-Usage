# Research: Interface en français

## R1. Durées et anciennetés (« dans 2 h 14 min », « il y a 12 min »)

- **Decision**: table de libellés par langue dans `NotchUsageCore` (`TimeLabels`, anglais et français),
  choisie à partir du code de langue. `RelativeTimeFormatter` prend la langue en paramètre.
- **Rationale**: les formateurs de Foundation donnent des résultats incohérents, mesurés le 2026-11-02 :

  | Style | en_US | fr_FR | fr_CA |
  |---|---|---|---|
  | `DateComponentsFormatter` abbreviated | 2h 14m | 2h 14min | 2h 14m |
  | brief | 2hr 14min | 2 h 14 min | 2 h 14min |
  | short | 2 hr, 14 min | 2 h et 14 min | 2 h et 14 min |
  | `Duration.units` narrow | 2h 14m | 2h 14min | 2h 14m |

  Aucun style ne garde l'anglais actuel (« 2h 14m ») et donne un français typographiquement correct
  (« 2 h 14 min ») pour toutes les régions françaises. Une table explicite est déterministe, testable en
  Swift Testing, et reste Foundation seul (constitution, contraintes techniques).
- **Alternatives considered**: catalogue de l'app pour les durées (non testable : l'app n'a pas de cible de
  tests) ; ressources localisées dans le package (ajoute un bundle de ressources au core pour 8 libellés).

## R2. Langue retenue

- **Decision**: l'app passe au core la langue réellement choisie pour son interface,
  `Bundle.main.preferredLocalizations.first` (« fr » ou « en »).
- **Rationale**: c'est la langue qu'applique le catalogue de textes ; les durées ne peuvent pas diverger du
  reste de l'interface, y compris avec le choix de langue par app de Réglages Système.
- **Alternatives considered**: `Locale.current.language` (peut différer de la langue de l'interface si la
  région et la langue ne concordent pas).

## R3. Catalogue de textes

- **Decision**: alimenter `Localizable.xcstrings` à partir des fichiers `.stringsdata` produits par la build
  (`SWIFT_EMIT_LOC_STRINGS`), avec `xcrun xcstringstool sync`, puis ajouter les traductions françaises.
- **Rationale**: le catalogue n'est rempli automatiquement que par l'IDE Xcode ; la synchronisation en ligne de
  commande garde le catalogue exact sans dépendre de l'IDE.
- **Alternatives considered**: saisie manuelle des clés (risque d'oubli ou de faute de clé).

## R4. Contrôle des traductions manquantes (FR-008)

- **Decision**: script `scripts/check-localizations.sh` qui synchronise le catalogue après build et échoue si
  une clé n'a pas de traduction française à l'état « translated » ; exécuté en CI après la build de l'app.
- **Rationale**: détecte un texte ajouté sans traduction avant fusion.

## R5. Dates et jours de la semaine

- **Decision**: inchangé, les vues formatent déjà les dates avec le format système (`.dateTime`), qui suit la
  langue et la région.
- **Rationale**: FR-005 est déjà satisfait par construction ; vérification manuelle au quickstart.
