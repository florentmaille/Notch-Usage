# Contract: endpoints externes d'usage

**Feature**: `001-claude-usage-notch` | **Date**: 2026-11-01

Endpoints non documentés par Anthropic, observés dans les outils open source (voir
[research.md](../research.md)). Toute requête sortante de l'app passe par l'un des deux
fournisseurs ci-dessous. Aucun autre hôte n'est autorisé (constitution I).

## Voie 1 : OAuth (jeton Claude Code)

### Lecture du jeton (local, Trousseau)

| Attribut | Valeur |
|---|---|
| `kSecClass` | `kSecClassGenericPassword` |
| `kSecAttrService` | `Claude Code-credentials` |
| `kSecAttrAccount` | login macOS (`NSUserName()`) ; ignorer l'entrée `account = "unknown"` |
| `kSecUseAuthenticationUI` | `.allow` sur action utilisateur, `.skip` en arrière-plan |

Contenu (JSON) :

```json
{
  "claudeAiOauth": {
    "accessToken": "sk-ant-oat01-…",
    "refreshToken": "sk-ant-ort01-…",
    "expiresAt": 1762000000000,
    "scopes": ["user:inference", "user:profile"],
    "subscriptionType": "max",
    "rateLimitTier": "…"
  }
}
```

Règles : seul `accessToken` et `subscriptionType` sont lus. `refreshToken` n'est **jamais**
copié ni utilisé. `expiresAt` en ms (parfois float) sert seulement à anticiper un 401.
Entrée sans `claudeAiOauth` (Claude Code ≥ 2.1.x avec `mcpOAuth` seul) ⇒ erreur
`credentialsUnavailable`.

### Requête

```http
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <accessToken>
anthropic-beta: oauth-2025-04-20
Accept: application/json
User-Agent: claude-cli/2.1.0 (external, cli)
```

## Voie 2 : Web (cookie `sessionKey`)

### Capture du cookie

`WKWebView` sur `https://claude.ai/login`, `WKWebsiteDataStore.default()`. À chaque
`cookiesDidChange` et `didFinish`, chercher un cookie `name == "sessionKey"`, domaine
`claude.ai`, valeur préfixée `sk-ant-sid` + version (`sid01`, `sid02` relevé le 2026-11-02). Dès capture : stocker, fermer la fenêtre.

### Requêtes

```http
GET https://claude.ai/api/organizations
GET https://claude.ai/api/organizations/{uuid}/usage
Cookie: sessionKey=<valeur>
Accept: */*
Content-Type: application/json
anthropic-client-platform: web_claude_ai
anthropic-client-version: 1.0.0
Origin: https://claude.ai
Referer: https://claude.ai/settings/usage
Sec-Fetch-Dest: empty
Sec-Fetch-Mode: cors
Sec-Fetch-Site: same-origin
User-Agent: <UA Chrome macOS courant>
```

Réponse `organizations` : tableau d'objets `{uuid, name, capabilities: [String],
rate_limit_tier}`. Choisir la première org dont `capabilities` contient `claude_pro` ou un
élément préfixé `claude_max`. Aucune ⇒ `unsupported`.

## Format de réponse `usage` (commun aux deux voies)

### Forme actuelle (prioritaire)

```json
{
  "limits": [
    {"kind": "session",       "percent": 27.5, "resets_at": "2026-11-01T14:00:00Z"},
    {"kind": "weekly_all",    "percent": 12,   "resets_at": "2026-11-06T00:00:00Z"},
    {"kind": "weekly_scoped", "percent": 44,   "resets_at": "2026-11-06T00:00:00Z",
     "scope": {"model": {"id": "…", "display_name": "Fable"}, "surface": null}}
  ],
  "extra_usage": {"is_enabled": false, "used_credits": null, "monthly_limit": null,
                  "utilization": null}
}
```

### Forme legacy

```json
{
  "five_hour":        {"utilization": 8.0, "resets_at": "2026-11-01T14:00:00Z"},
  "seven_day":        {"utilization": 7.0, "resets_at": "2026-11-06T00:00:00Z"},
  "seven_day_opus":   null,
  "seven_day_sonnet": {"utilization": 1.0, "resets_at": "2026-11-06T00:00:00Z"},
  "seven_day_cowork": null,
  "seven_day_oauth_apps": null,
  "extra_usage": {"is_enabled": false}
}
```

### Mapping → `UsageLimit`

| Source | `id` | `kind` | `modelName` |
|---|---|---|---|
| `limits[kind=session]` | `session` | `rollingFiveHour` | — |
| `limits[kind=weekly_all]` | `weekly_all` | `weeklyAll` | — |
| `limits[kind=weekly_scoped]` | `weekly_scoped:<display_name>` | `weeklyModel` | `scope.model.display_name` |
| `five_hour` | `session` | `rollingFiveHour` | — |
| `seven_day` | `weekly_all` | `weeklyAll` | — |
| `seven_day_<x>` (non null) | `weekly_scoped:<x>` | `weeklyModel` | `<x>` capitalisé |

Règles du parseur :
1. `limits[]` présent et non vide ⇒ seule source ; clés plates ignorées.
2. `percent` / `utilization` : nombre, borné à 0…100. Valeur ≤ 1 **et** toutes les valeurs
   ≤ 1 ⇒ suspecter une fraction, multiplier par 100 et journaliser (incertitude cc-pool).
3. `resets_at` : ISO 8601 (avec ou sans fraction, `Z` ou offset), epoch secondes (< 10¹¹)
   ou millisecondes. Absent ou invalide ⇒ `nil`.
4. Clés inconnues, `extra_usage`, `kind` inconnu ⇒ ignorés. `seven_day_cowork`,
   `seven_day_oauth_apps`, `seven_day_routines` ⇒ ignorés (pas des modèles).
5. Zéro limite exploitable ⇒ `ParseError.noLimits` → `FetchState.unsupported`.

## Mapping des réponses HTTP → `FetchError`

| HTTP | Condition | `FetchError` | Effet |
|---|---|---|---|
| 200 JSON | parse OK | — | `idle(snapshot)` |
| 200 | `Content-Type: text/html` ou `cf-mitigated: challenge` | `.challenge` | `failed`, propose de rouvrir la connexion navigateur |
| 200 / 204 | corps vide | `.emptyBody` | `failed`, dernier relevé conservé |
| 401, 403 | | `.unauthorized` | voie 1 : relecture silencieuse du Trousseau Claude Code ; sinon `reauthRequired` |
| 429 | `Retry-After` optionnel | `.rateLimited(retryAfter:)` | backoff (R4) |
| 5xx | | `.server(status)` | backoff |
| réseau | `URLError` | `.network(URLError.Code)` | backoff, `waitsForConnectivity` |
| JSON invalide | | `.malformed` | `failed`, dernier relevé conservé |

## Fixtures (Tests/NotchUsageCoreTests/Fixtures)

| Fichier | Couvre |
|---|---|
| `usage-limits-fable.json` | forme actuelle, 1 `weekly_scoped` Fable |
| `usage-limits-two-models.json` | 2 `weekly_scoped`, ordre d'affichage |
| `usage-legacy.json` | forme legacy avec `seven_day_sonnet`, `seven_day_opus: null` |
| `usage-both-forms.json` | `limits[]` + clés plates ⇒ pas de doublon |
| `usage-fraction.json` | `utilization` en 0…1 |
| `usage-epoch-ms.json` | `resets_at` en epoch ms |
| `usage-no-limits.json` | compte sans limites ⇒ `unsupported` |
| `usage-malformed.json` | JSON tronqué |
| `usage-cloudflare.html` | challenge |
| `usage-429.json` | corps d'erreur `rate_limit_error` |
| `organizations.json` | org Team avant org perso Max |
| `claude-code-credentials.json` | entrée Trousseau complète |
| `claude-code-credentials-mcp-only.json` | entrée sans `claudeAiOauth` |
