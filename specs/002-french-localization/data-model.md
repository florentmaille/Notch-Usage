# Data Model: Interface en français

## Catalogue de textes (`Localizable.xcstrings`)

| Champ | Description | Règle |
|---|---|---|
| clé | Texte anglais source, tel qu'écrit dans le code | Unique ; inchangé par rapport à 0.1.0 (FR-007) |
| `en` | Valeur anglaise | Égale à la clé |
| `fr` | Traduction française | Obligatoire, état `translated` (FR-008, SC-003) |
| variantes de pluriel | `one` / `other` si un nombre est interpolé | Requises seulement si la forme change entre 1 et plusieurs |

Noms propres jamais traduits : Claude, Claude Code, claude.ai, Notch Usage, Keychain → « Trousseau ».

## Libellés de durée (`TimeLabels`, core)

| Champ | Anglais | Français |
|---|---|---|
| minutes | `{m}m` | `{m} min` |
| heures + minutes | `{h}h {m}m` | `{h} h {m} min` |
| jours + heures | `{d}d {h}h` | `{d} j {h} h` |
| avant réinitialisation | `in {durée}` | `dans {durée}` |
| réinitialisation imminente | `reset pending` | `réinitialisation imminente` |
| inconnu | `—` | `—` |
| ancienneté | `{durée} ago` | `il y a {durée}` |
| à l'instant | `just now` | `à l'instant` |

Langue : code `fr` (toutes régions) → français ; tout autre code → anglais.
