import Testing
@testable import NotchUsageCore

@Suite("SessionKeyFormat")
struct SessionKeyFormatTests {
    @Test func acceptsKnownVersions() {
        #expect(SessionKeyFormat.isValid("sk-ant-sid01-" + String(repeating: "a", count: 40)))
        // Format relevé le 2026-11-02 sur claude.ai.
        #expect(SessionKeyFormat.isValid("sk-ant-sid02-" + String(repeating: "a", count: 118)))
    }

    @Test func rejectsOtherTokens() {
        #expect(!SessionKeyFormat.isValid("sk-ant-rh-eyJabcdefghijklmnopqrstuvwxyz"))
        #expect(!SessionKeyFormat.isValid("sk-ant-oat01-abcdefghijklmnopqrstuvwxyz"))
        #expect(!SessionKeyFormat.isValid("sk-ant-sid02-"))
        #expect(!SessionKeyFormat.isValid("hello"))
    }

    @Test func rejectsHeaderBreakingCharacters() {
        let body = String(repeating: "a", count: 40)
        #expect(!SessionKeyFormat.isValid("sk-ant-sid02-" + body + "; Path=/"))
        #expect(!SessionKeyFormat.isValid("sk-ant-sid02-" + body + "\r\nX-Injected: 1"))
        #expect(!SessionKeyFormat.isValid("sk-ant-sid02-" + body + " " + body))
        #expect(SessionKeyFormat.isValid("sk-ant-sid02-" + body + "_-Z9"))
    }

    @Test func trimsWhitespace() {
        #expect(SessionKeyFormat.normalized("  sk-ant-sid02-abcdefghijklmnopqrstuvwxyz\n") == "sk-ant-sid02-abcdefghijklmnopqrstuvwxyz")
    }

    /// Le cookie capturé doit venir de claude.ai ou d'un sous-domaine : un simple suffixe acceptait `evilclaude.ai`.
    @Test func cookieDomainMustBeClaudeOrASubdomain() {
        for domain in ["claude.ai", ".claude.ai", "api.claude.ai", ".API.Claude.AI"] {
            #expect(SessionKeyFormat.isClaudeCookieDomain(domain), Comment(rawValue: domain))
        }
        for domain in ["evilclaude.ai", "claude.ai.evil.com", "claude.aix", "ai", ""] {
            #expect(!SessionKeyFormat.isClaudeCookieDomain(domain), Comment(rawValue: domain))
        }
    }
}
