# Implementation Plan: Connexion sans trace sur disque

**Branch**: `007-secure-login` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary

Correctifs de la revue sécurité, sans changement visible : magasin WebKit en mémoire pour la fenêtre
de connexion et purge des restes des versions antérieures (`BrowserLoginWindow.purgeBrowserData`),
cask complet, CI à droits minimaux et actions épinglées, validations strictes de la clé collée et de
l'identifiant d'organisation, attribut Trousseau trompeur retiré.

## Technical Context

**Language/Version**: Swift 6 | **Dependencies**: WebKit, Security, Foundation | **Storage**: rien d'ajouté, du retiré
**Testing**: `SessionKeyFormatTests` (caractères interdits) ; vérification manuelle des fichiers sur disque ; CI
**Constraints**: aucun texte nouveau ; aucun changement de comportement visible

## Constitution Check

| Principe | Vérification | Statut |
|---|---|---|
| I. Vie privée | Rétablit « Trousseau uniquement » ; purge des restes | PASS |
| II. Sobriété | Une purge asynchrone au lancement, sans effet si rien | PASS |
| III. Tests | Format de clé testé ; la purge WebKit n'est pas testable en core (manuel) | PASS |
| IV. YAGNI | Aucune abstraction ; sandbox et notarisation reportés, justifiés dans la spec | PASS |

## Project Structure

```text
App/NotchUsage/Auth/BrowserLoginWindow.swift     # nonPersistent, purgeBrowserData
App/NotchUsage/Auth/KeychainCredentialStore.swift # attribut retiré
App/NotchUsage/AppModel.swift                     # purge au lancement, déconnexion, 401
Sources/NotchUsageCore/Credentials/SessionKeyFormat.swift
Sources/NotchUsageCore/Providers/WebUsageProvider.swift
Tests/NotchUsageCoreTests/SessionKeyFormatTests.swift
scripts/cask/notch-usage.rb.template
.github/workflows/ci.yml
README.md
```

## Research

- **R1 magasin** : `WKWebsiteDataStore.nonPersistent()` ; `httpCookieStore` et son observateur fonctionnent à l'identique. Les cookies périmés ne sont plus recapturés (magasin neuf à chaque ouverture), donc l'ancien `clearClaudeCookies` devient une purge de l'ancien magasin persistant.
- **R2 purge** : `WKWebsiteDataStore.default().removeData(allTypes, for: records)` + `modifiedSince: .distantPast` + `HTTPCookieStorage.shared.removeCookies(since:)`. Le fichier `binarycookies` peut subsister vide : géré par le système.
- **R3 CI arm64** : job `macos-15` en `continue-on-error` ; les jobs bloquants restent Intel (capacité).
- **R4 Trousseau** : `kSecAttrAccessible` est ignoré sans `kSecUseDataProtectionKeychain` ; le data-protection keychain attend un Team ID stable (release signée).
