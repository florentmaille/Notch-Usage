# Spike : signaler la fin d'une réponse du chat Claude par un connecteur MCP

**Date** : 2026-11-05 · **Statut** : clos, piste non retenue

**Question** : le chat de l'app Claude n'exécute aucun hook. Un serveur MCP local, que le modèle appelle en
fin de réponse, peut-il remplacer le hook `Stop` de Claude Code, et à quelle fiabilité ?

**Pistes écartées avant le spike** (vérifiées le 2026-11-05) : les journaux de l'app Claude
(`~/Library/Logs/Claude/claude.ai-web.log`) n'enregistrent que les erreurs et avertissements ; la base des
notifications macOS est protégée par le système ; la config de l'app ne contient rien d'exploitable.
L'Accessibilité sur la fenêtre de l'app est écartée par principe (lecture de l'écran des conversations).

## Ce que contient le dossier

| Fichier | Rôle |
|---|---|
| `notch_chat_mcp.py` | serveur MCP stdio, bibliothèque standard Python ; un outil `notch_reply_done(conversation_title)` qui écrit un événement `Stop` dans `claude-events.jsonl` (format du hook) et une ligne dans `chat-mcp-spike.log` |
| `install.sh` | quitte l'app Claude, sauvegarde sa config, copie le serveur dans le conteneur de Notch Usage, déclare `notch-usage-chat`, relance l'app |
| `uninstall.sh` | quitte l'app Claude, retire l'entrée et les fichiers du spike, relance l'app |

Vérifié avant la mesure : handshake MCP, liste d'outils, appel, outil inconnu, ligne illisible, `ping` ;
événement lu par le core (`aChatReplyFromTheMCPSpikeIsADoneSessionNamedByItsTitle`) ; fusion de la config
répétée sur une copie, retrait identique à l'octet.

## Protocole

1. Dans **Terminal.app** (pas dans l'app Claude, que le script quitte) :
   `sh specs/017-claude-attention/spike-mcp/install.sh`
2. Dans l'app Claude, onglet Chat, nouvelle conversation. Vérifier que `notch-usage-chat` est actif dans
   le menu des outils de la conversation.
3. **Phase A, description seule** : envoyer 10 messages variés (question courte, demande longue, code,
   recherche web, reformulation, « merci », une question qui appelle une réponse d'un mot…). Au premier
   appel, l'app demande la permission : choisir « Toujours autoriser ».
4. Compter les appels : `wc -l < ~/Library/Application\ Support/NotchUsage/chat-mcp-spike.log`
5. **Phase B**, seulement si la phase A donne moins de 9 sur 10 : ajouter dans Réglages → Profil →
   préférences personnelles « À la fin de chaque réponse, appelle l'outil notch_reply_done. », puis
   refaire 10 messages dans une nouvelle conversation.
6. Si « Follow Claude Code » est actif dans Notch Usage, observer l'île : coche blanche, titre de la
   conversation au survol, clic sur la ligne qui ramène l'app Claude.
7. Fin du spike : `sh specs/017-claude-attention/spike-mcp/uninstall.sh`

## Critères de décision

| Résultat | Décision |
|---|---|
| ≥ 9/10 en phase A | piste retenue : spec d'une feature « chat » (serveur en Swift dans le bundle, installation par un réglage) |
| ≥ 9/10 en phase B seulement | retenue si l'instruction de profil est acceptable pour l'utilisateur |
| < 9/10 dans les deux phases | abandon : le signal raterait trop de réponses pour être utile |

À noter dans tous les cas : le titre est-il stable d'un appel à l'autre (une seule ligne par conversation
dans le panneau) ; l'appel est-il visible et gênant dans la conversation ; le délai entre la fin du texte et
l'apparition de la coche.

## Limites connues

- Seul « terminé » est couvert : les approbations du chat ne passent pas par le serveur.
- Le chat n'émet pas d'équivalent de `UserPromptSubmit` : la coche reste jusqu'à un clic sur l'île.
- Le titre vient du modèle ; deux titres différents pour une même conversation donnent deux lignes.

## Résultats

### Installation (2026-11-05, 18 h 11)

- `install.sh` exécuté depuis Terminal.app : config sauvegardée, entrée ajoutée, app Claude relancée.
- L'app Claude lance le serveur au démarrage : `initialize`, `notifications/initialized`, `tools/list` réussis
  (`~/Library/Logs/Claude/mcp-server-notch-usage-chat.log`).
- **Constat inattendu** : l'outil est aussi exposé aux sessions de l'onglet Code, qui lisent la même config.
  Ces sessions ont déjà le hook `Stop` : une feature devra limiter l'outil au chat ou ignorer ses appels quand
  la session a un hook, sinon chaque fin de tour Code compterait deux fois. Dans cette session de spike,
  l'outil n'a pas été appelé (la consigne de sa description n'est pas une instruction de l'utilisateur).

### Mesure, phase A (description de l'outil seule)

- 3 messages envoyés dans l'onglet Chat : **0 appel**. Aucune demande de permission n'est apparue, ce qui
  confirme que le modèle n'a jamais tenté l'appel (le premier appel en déclenche une).
- Le serveur était connecté (`LocalMcpServerManager … Connected to notch-usage-chat (1 tools)`,
  `localMcpBridge announcing`) : l'échec ne vient pas du transport.
- Reste à trancher : l'outil était-il proposé au modèle dans cette conversation (connecteur actif), ou le
  modèle ignore-t-il la consigne de la description ? Test suivant : demander explicitement l'appel.
- Lecture provisoire : une consigne placée dans la description d'un outil ne suffit pas. Cohérent avec le
  comportement attendu d'un modèle, qui traite les descriptions d'outils comme des données et non comme des
  instructions de l'utilisateur.

### Appel explicite et phase B (instruction de profil), 18 h 21 à 18 h 25

- **Appel explicite** (« Appelle l'outil notch_reply_done… ») : appel réussi, résultat « ok ». Aucune demande de
  permission : l'app Claude autorise d'emblée cet outil local.
- **Phase B** : 2 messages, **2 appels automatiques** en fin de réponse. Titre stable : « Test de connexion »
  les deux fois, donc une seule ligne dans le panneau.
- **Bout en bout** : l'encoche affiche « ✓ 2 » ; le panneau liste « Test notch » et « Test de connexion »,
  « finished », avec la durée écoulée. Le fichier d'événements est vidé après lecture.
- **Défaut** : après l'appel, le modèle **réécrit toute sa réponse**. Le résultat « ok » le relançait.
  Corrigé en 0.0.2-spike : la description et le résultat disent que la réponse est déjà affichée et qu'il
  faut terminer sans rien écrire. À revérifier après réinstallation.
- **Coût visible** : une ligne « notch-usage-chat: Notch reply done » sous chaque réponse, et parfois une étape
  « Chargé des outils » avant la réponse.
- **Échantillon** : 2 messages automatiques sur les 10 prévus. La décision attend la mesure complète.
- **Nommage** : la section du panneau s'appelle « Claude Code » alors qu'elle liste aussi des chats.

### Version 0.0.2 (après redémarrage de l'app Claude, 18 h 28)

- Arrêter le processus du serveur ne suffit pas : l'app Claude ne le relance pas (« Server disconnected »).
  Toute mise à jour du serveur exige un redémarrage complet de l'app Claude.
- Serveur 0.0.2 chargé à 18 h 28 min 54 s.
- **5 appels** entre 18 h 29 min 35 s et 18 h 29 min 47 s, dans deux conversations : « Test rapide » (3) et
  « Test nouveau message » (2). Titre stable dans chaque conversation.
- À confirmer par l'utilisateur : nombre de messages envoyés (le dénominateur), et disparition de la réponse
  dupliquée.

### Version 0.0.3 : titre et identifiant de conversation (18 h 34)

- **Demande** : afficher dans l'encoche le titre de la barre latérale de l'app Claude (« Nouveau test 1 »),
  comme pour les sessions Code, dont le hook transmet ce titre (`session_title`).
- **Requête de l'app** : `tools/call` ne contient que `name` et `arguments`, **sans `_meta`**. Aucun
  identifiant ni titre de conversation n'est transmis au serveur.
- **Titre du modèle** : avec la consigne « titre de la barre latérale, sinon résumé du premier message », un
  message dans « Nouveau test 1 » a donné « Test 1 préférences OntraaK ». Le modèle ne connaît pas le titre
  de la barre latérale ; seule la coïncidence de « Test rapide » l'avait fait correspondre.
- **Source du vrai titre** : uniquement le stockage interne de la page web de l'app Claude (IndexedDB,
  Session Storage). Écartée : format non documenté, contenu des conversations, écrit en continu.
- **Deux clients** : à chaque démarrage, l'app lance deux instances du serveur, `claude-ai` (chat) et
  `local-agent-mode-notch-usage-chat` (mode agent local). Les sessions de ce second mode recevraient aussi l'outil.

### Conclusion provisoire

| Critère | Constat |
|---|---|
| Fiabilité de l'appel | 0/3 sans instruction de profil ; avec instruction, tous les appels observés (taux exact non mesuré) |
| Nom affiché | approximatif, inventé par le modèle ; le titre de la barre latérale est inaccessible proprement |
| Regroupement par conversation | dépend de la stabilité du titre du modèle, aucun identifiant transmis |
| Coût visible | une ligne d'outil sous chaque réponse ; réponse dupliquée en 0.0.1, corrigée en 0.0.2 |
| Mise à jour du serveur | redémarrage complet de l'app Claude |
| Effet de bord | l'outil est aussi proposé aux sessions Code et au mode agent local |

Recommandation : ne pas en faire une feature. Le signal « terminé » du chat reste approximatif (nom, regroupement),
dépend d'une instruction de profil et ajoute une ligne visible à chaque réponse. La 017 reste limitée à Claude Code.

### Clôture (18 h 36)

- `uninstall.sh` lancé depuis Terminal.app : entrée `notch-usage-chat` retirée, serveur et journal du spike
  supprimés, aucun processus restant. `mcpServers` identique à la sauvegarde du 18 h 11.
- Sauvegarde conservée : `claude_desktop_config.json.before-notch-spike-20261105-181125`.
- À faire côté utilisateur : retirer l'instruction `notch_reply_done` du profil Claude.

