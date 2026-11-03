# Tasks: Connexion sans trace sur disque

**Input**: [spec.md](spec.md), [plan.md](plan.md)

## Phase 1: US1 - Rien sur disque hors Trousseau

- [x] T001 [US1] `App/NotchUsage/Auth/BrowserLoginWindow.swift` : `websiteDataStore = .nonPersistent()` ; effacement du magasin à la capture ; `clearClaudeCookies` → `purgeBrowserData` (tous enregistrements du magasin persistant + `modifiedSince` + cookies partagés)
- [x] T002 [US1] `App/NotchUsage/AppModel.swift` : purge au `start()`, à la déconnexion et sur 401
- [x] T003 [US1] `scripts/cask/notch-usage.rb.template` : aligné sur le tap (zip, `uninstall quit`, zap complet) + caveat Trousseau
- [x] T004 [US1] Vérification manuelle : lancer la build Debug, constater la purge de `~/Library/WebKit/com.notchusage.app/WebsiteData` et des cookies ; résultats dans spec.md (section Validation)

## Phase 2: US2 - Validations et CI

- [x] T005 [US2] Test `rejectsHeaderBreakingCharacters` dans `Tests/NotchUsageCoreTests/SessionKeyFormatTests.swift`, puis `SessionKeyFormat.isValid` restreint aux caractères sûrs
- [x] T006 [US2] `Sources/NotchUsageCore/Providers/WebUsageProvider.swift` : `UUID(uuidString:)` sur l'identifiant serveur et sur l'identifiant mémorisé
- [x] T007 [US2] `App/NotchUsage/Auth/KeychainCredentialStore.swift` : retrait de `kSecAttrAccessible`
- [x] T008 [US2] `.github/workflows/ci.yml` : `permissions: contents: read`, `actions/checkout` épinglé sur SHA, job arm64 non bloquant
- [x] T009 [US2] `README.md` : phrase sur la fenêtre de connexion (cookies en mémoire)

## Phase 3: Polish

- [x] T010 `swift test` vert, build Debug, `scripts/check-localizations.sh` (aucun texte nouveau)
