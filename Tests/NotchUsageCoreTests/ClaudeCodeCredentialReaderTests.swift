import Foundation
import Testing
@testable import NotchUsageCore

@Suite("ClaudeCodeCredentialReader")
struct ClaudeCodeCredentialReaderTests {
    @Test func fullEntry() throws {
        let token = try ClaudeCodeCredentialReader.accessToken(from: Fixture.data("claude-code-credentials.json"))
        #expect(token.accessToken == "sk-ant-oat01-FIXTURE-ACCESS-TOKEN")
        #expect(token.subscriptionType == .max)
        #expect(token.expiresAt == Date(timeIntervalSince1970: 1_762_005_600))
    }

    @Test func refreshTokenNeverExposed() throws {
        let token = try ClaudeCodeCredentialReader.accessToken(from: Fixture.data("claude-code-credentials.json"))
        let mirror = Mirror(reflecting: token)
        #expect(!mirror.children.contains { "\($0.value)".contains("ort01") })
        #expect(!mirror.children.contains { $0.label?.lowercased().contains("refresh") == true })
    }

    @Test func mcpOnlyEntry() {
        #expect(throws: CredentialError.missingOAuthSection) {
            try ClaudeCodeCredentialReader.accessToken(from: Fixture.data("claude-code-credentials-mcp-only.json"))
        }
    }

    @Test func invalidJSON() {
        #expect(throws: CredentialError.invalidJSON) {
            try ClaudeCodeCredentialReader.accessToken(from: Data("{not json".utf8))
        }
    }

    @Test func teamSubscription() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x","subscriptionType":"team"}}"#
        let token = try ClaudeCodeCredentialReader.accessToken(from: Data(json.utf8))
        #expect(token.subscriptionType == .team)
        #expect(token.expiresAt == nil)
    }

    @Test func unknownSubscriptionIsUnsupported() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x","subscriptionType":"free"}}"#
        let token = try ClaudeCodeCredentialReader.accessToken(from: Data(json.utf8))
        #expect(token.subscriptionType == .unsupported)
    }

    @Test func expiry() throws {
        let token = try ClaudeCodeCredentialReader.accessToken(from: Fixture.data("claude-code-credentials.json"))
        let exp = Date(timeIntervalSince1970: 1_762_005_600)
        #expect(!token.isExpired(at: exp.addingTimeInterval(-120)))
        // Marge de 60 s : un jeton qui expire dans la minute est déjà inutilisable pour un relevé.
        #expect(token.isExpired(at: exp.addingTimeInterval(-30)))
        #expect(token.isExpired(at: exp.addingTimeInterval(3600)))
    }

    @Test func noExpiryIsNeverExpired() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x"}}"#
        let token = try ClaudeCodeCredentialReader.accessToken(from: Data(json.utf8))
        #expect(!token.isExpired(at: .distantFuture))
    }
}
