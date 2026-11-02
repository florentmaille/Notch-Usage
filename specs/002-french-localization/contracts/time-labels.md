# Contract: durées localisées (NotchUsageCore)

```swift
public enum InterfaceLanguage: Sendable, Equatable {
    case english, french
    /// "fr", "fr-CA", "fr_BE"… → .french ; tout le reste → .english
    public init(code: String?)
}

public enum RelativeTimeFormatter {
    public static func untilReset(_ date: Date?, now: Date, language: InterfaceLanguage = .english) -> String
    public static func age(_ date: Date, now: Date, language: InterfaceLanguage = .english) -> String
}
```

| Entrée | `.english` | `.french` |
|---|---|---|
| reset dans 0 s ou passé | reset pending | réinitialisation imminente |
| reset dans 30 s | in 1m | dans 1 min |
| reset dans 2 h 14 min | in 2h 14m | dans 2 h 14 min |
| reset dans 4 j 3 h | in 4d 3h | dans 4 j 3 h |
| reset inconnu | — | — |
| relevé il y a 20 s | just now | à l'instant |
| relevé il y a 12 min | 12 min ago | il y a 12 min |
| relevé il y a 3 h | 3 h ago | il y a 3 h |
| relevé il y a 2 j | 2 d ago | il y a 2 j |

La valeur par défaut `.english` garde les appels existants et l'anglais identiques à 0.1.0 (FR-007).
