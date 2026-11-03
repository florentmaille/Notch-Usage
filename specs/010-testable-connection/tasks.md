# Tasks: Connexion testable

- [x] T001 `Sources/NotchUsageCore/Connection/ConnectionManager.swift` (déplacé depuis l'app) : `ConnectionError` sans texte, `throws(ConnectionError)`, `now` et `log` injectés
- [x] T002 `ClaudeCodeCredentialSource.entryExists()` ; `ClaudeCodeKeychainReader` conforme
- [x] T003 `Tests/NotchUsageCoreTests/ConnectionManagerTests.swift` (9 tests) + `StubClaudeCodeSource`
- [x] T004 `ProviderSupport.check` partagé ; `WebUsageProvider.resolveOrganization` l'utilise
- [x] T005 `App/NotchUsage/Auth/ConnectionError+Messages.swift` : messages, dont 3 cas réseau ; catalogue fr
- [x] T006 `NotchRootView` : `onGeometryChange`, `ExpandedHeightKey` retiré
- [x] T007 Cible `NotchUsageAppTests` (`project.yml`, `Tests/NotchUsageAppTests`), hôte inerte sous XCTest, étape CI « App tests »
- [x] T008 221 tests core, 5 tests app, build, 92 textes traduits
