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

    @Test func unknownSubscriptionIsUnsupported() throws {
        let json = #"{"claudeAiOauth":{"accessToken":"sk-ant-oat01-x","subscriptionType":"team"}}"#
        let token = try ClaudeCodeCredentialReader.accessToken(from: Data(json.utf8))
        #expect(token.subscriptionType == .unsupported)
        #expect(token.expiresAt == nil)
    }
}
