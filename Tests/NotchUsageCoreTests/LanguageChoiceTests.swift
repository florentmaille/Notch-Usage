import Testing
@testable import NotchUsageCore

@Suite("LanguageChoice")
struct LanguageChoiceTests {
    @Test func systemHasNoOverride() {
        #expect(LanguageChoice.system.appleLanguages == nil)
    }

    @Test func explicitChoicesOverride() {
        #expect(LanguageChoice.english.appleLanguages == ["en"])
        #expect(LanguageChoice.french.appleLanguages == ["fr"])
    }

    @Test func readsStoredOverride() {
        #expect(LanguageChoice(appleLanguages: nil) == .system)
        #expect(LanguageChoice(appleLanguages: []) == .system)
        #expect(LanguageChoice(appleLanguages: ["fr"]) == .french)
        #expect(LanguageChoice(appleLanguages: ["fr-CA", "en"]) == .french)
        #expect(LanguageChoice(appleLanguages: ["en-GB"]) == .english)
    }

    /// Une préférence posée hors de l'app (ex. `defaults write`) dans une langue non prise en charge vaut « Système ».
    @Test func unsupportedOverrideIsSystem() {
        #expect(LanguageChoice(appleLanguages: ["de"]) == .system)
    }
}
