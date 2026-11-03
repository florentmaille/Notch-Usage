<!--
Sync Impact Report
- Version : 1.1.0 → 1.1.1 (PATCH : plancher de l'intervalle aligné sur le code)
- Principe modifié : II. Sobriété des ressources. Le plancher de l'intervalle de rafraîchissement
  est 60 s (`RefreshSettings.minimumInterval`), pas 30 s : l'endpoint est partagé avec Claude Code.
- Artefacts : aucun autre changement (specs/009-appmodel-debt)

Précédent :
- Version : 1.0.0 → 1.1.0 (MINOR : règle mémoire élargie)
- Principe modifié : II. Sobriété des ressources. La mémoire se mesure en empreinte physique
  (Moniteur d'activité, `vmmap --summary`) et non plus en mémoire résidente (RSS).
- Raison : le RSS compte les pages partagées des frameworks système (SwiftUI, AppKit), communes
  à toutes les apps. Mesure du 2026-11-02 en Release : RSS 84 Mo, empreinte 19,7 Mo.
- Artefacts mis à jour : specs/001-claude-usage-notch/plan.md, tasks.md, quickstart.md
- Templates : aucun changement requis
-->
# Notch-Usage Constitution

## Core Principles

### I. Local-first et vie privée (NON-NEGOTIABLE)

- L'app MUST NOT envoyer de données à un serveur tiers. Seuls les endpoints officiels
  d'Anthropic nécessaires pour lire la consommation sont autorisés.
- Aucune télémétrie, aucun analytics, aucun crash reporter distant.
- Les secrets (clés API, jetons OAuth, cookies de session) MUST être stockés uniquement
  dans le Trousseau macOS. Ils ne doivent jamais apparaître en clair sur disque, dans les
  logs ou dans les messages d'erreur.
- L'historique de consommation est stocké en local, dans le conteneur de l'app,
  et l'utilisateur peut l'effacer depuis l'app.
- Toute nouvelle connexion réseau MUST être justifiée dans la spec et le plan de la feature.

**Rationale** : l'app manipule des identifiants Anthropic et des données d'usage. La
confiance des utilisateurs d'un outil open source repose sur cette garantie, qu'on peut
vérifier dans le code.

### II. Sobriété des ressources

- Au repos, la consommation CPU moyenne MUST rester sous 1 %, et l'empreinte mémoire
  (colonne « Mémoire » du Moniteur d'activité, `vmmap --summary`) sous 60 Mo. Le RSS brut
  n'est pas retenu : il inclut les frameworks système partagés.
- Pas de polling plus fréquent que toutes les 60 s par défaut. L'intervalle est configurable,
  avec un plancher de 60 s, et un backoff s'applique en cas d'erreur ou de rate limit.
- Le rafraîchissement est suspendu pendant la veille, l'écran verrouillé ou le mode
  économie d'énergie.
- Les animations de l'encoche MUST s'arrêter dès que la vue est repliée.
- Les budgets ci-dessus sont vérifiés avec Instruments avant chaque release.

**Rationale** : une app qui reste dans l'encoche en permanence ne doit jamais se faire
remarquer par son coût sur la batterie.

### III. Tests d'abord (NON-NEGOTIABLE)

- La logique métier suit le TDD (rouge → vert → refactor) : parsing des réponses d'usage,
  calcul des quotas et des fenêtres de réinitialisation, seuils d'alerte, persistance.
- La logique métier MUST vivre dans des modules sans dépendance à SwiftUI ni à AppKit,
  et être testable avec Swift Testing ou XCTest.
- Le réseau est testé avec des fixtures JSON versionnées, jamais contre l'API réelle en CI.
- Une PR qui modifie la logique métier sans tests est refusée.

**Rationale** : les formats d'usage d'Anthropic peuvent changer sans préavis. Des tests
sur fixtures détectent une régression avant les utilisateurs.

### IV. Simplicité (YAGNI)

- Chaque dépendance externe MUST être justifiée dans le plan. La règle par défaut est
  « Foundation, SwiftUI et AppKit d'abord ».
- Pas d'abstraction pour un deuxième fournisseur, un deuxième OS ou un deuxième usage
  tant qu'il n'est pas spécifié.
- Pas de plugin, de framework d'injection ou de couche d'architecture sans besoin démontré.
- Toute complexité ajoutée est notée dans la section « Complexity Tracking » du plan.

**Rationale** : un utilitaire d'encoche a une surface fonctionnelle réduite. Le maintenir
simple est la condition pour qu'un contributeur occasionnel puisse s'y retrouver.

## Contraintes techniques et distribution

- **Stack** : Swift 6 en concurrence stricte, SwiftUI avec AppKit là où l'encoche l'exige
  (fenêtres de type NSPanel). Gestion des paquets uniquement via Swift Package Manager.
- **Cible** : macOS 14 (Sonoma) minimum, Apple Silicon et Intel. Le comportement sur les
  écrans sans encoche est défini dans la spec.
- **Distribution** : open source sur GitHub. Les releases sont signées avec un Developer ID,
  notarisées par Apple, et publiées sous forme de DMG et de cask Homebrew.
- **Licence** : MIT (fichier `LICENSE` à la racine).
- **Sécurité** : Hardened Runtime activé. Les entitlements sont réduits au strict minimum
  et justifiés dans le plan.

## Workflow de développement

- Chaque feature suit le cycle Spec Kit : `/speckit-specify` → `/speckit-plan` →
  `/speckit-tasks` → `/speckit-implement`.
- Le plan MUST contenir une section « Constitution Check » qui confronte la feature
  aux principes I à IV.
- Le travail se fait sur une branche par feature, avec une PR obligatoire vers `main`.
  La CI (build et tests) doit passer avant le merge.
- Les commits suivent Conventional Commits (`feat:`, `fix:`, `docs:`, `test:`…).
- Toute régression des budgets du principe II bloque la release.

## Governance

- Cette constitution prévaut sur toute autre pratique du projet. En cas de conflit,
  la constitution s'applique, ou bien elle est amendée.
- Un amendement se fait par une PR dédiée qui modifie ce fichier, expose la raison du
  changement et met à jour la version.
- Versionnage sémantique :
  - **MAJOR** : un principe est supprimé ou redéfini de façon incompatible ;
  - **MINOR** : un principe ou une section est ajouté, ou une règle est élargie ;
  - **PATCH** : reformulation ou clarification sans effet sur le fond.
- Chaque revue de PR vérifie la conformité aux principes. Toute dérogation est justifiée
  dans la PR et tracée dans le plan.

**Version**: 1.1.1 | **Ratified**: 2026-11-01 | **Last Amended**: 2026-11-03
