import Testing
@testable import NotchUsageCore

@Suite("ClaudeCLI (011)")
struct ClaudeCLITests {
    @Test func knownLocationsComeBeforeThePath() {
        let c = ClaudeCLI.candidates(home: "/Users/a", path: "/usr/bin:/Users/a/.local/bin")
        #expect(c.first == "/Users/a/.local/bin/claude")
        #expect(c.contains("/opt/homebrew/bin/claude") && c.contains("/usr/bin/claude"))
        #expect(c.filter { $0 == "/Users/a/.local/bin/claude" }.count == 1)
    }

    @Test func locateReturnsTheFirstExecutable() {
        let found = ClaudeCLI.locate(home: "/Users/a", path: nil) { $0 == "/opt/homebrew/bin/claude" }
        #expect(found == "/opt/homebrew/bin/claude")
        #expect(ClaudeCLI.locate(home: "/Users/a", path: nil) { _ in false } == nil)
    }

    @Test func renewalSkipsMCPAndUserSettings() {
        let a = ClaudeCLI.renewalArguments
        #expect(a.contains("--strict-mcp-config") && a.contains("--no-session-persistence"))
        #expect(a[a.firstIndex(of: "--model")! + 1] == "haiku")
        #expect(a[a.firstIndex(of: "--setting-sources")! + 1] == "")
    }

    @Test func environmentCarriesTheUserForTheKeychain() {
        let env = ClaudeCLI.environment(home: "/Users/a", user: "a")
        #expect(env["USER"] == "a" && env["LOGNAME"] == "a" && env["HOME"] == "/Users/a")
        #expect(env.count == 4)
    }

    /// `claude` installé par npm ou bun : un script qui cherche `node` ou `bun` dans le PATH.
    @Test func pathStartsWithTheBinaryFolderAndHomebrew() {
        let env = ClaudeCLI.environment(home: "/Users/a", user: "a", binary: "/Users/a/.npm-global/bin/claude")
        #expect(env["PATH"] == "/Users/a/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
        #expect(ClaudeCLI.environment(home: "/Users/a", user: "a", binary: "/opt/homebrew/bin/claude")["PATH"]
                == "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    }

    @Test func outcomeFromExitAndOutput() {
        #expect(ClaudeCLI.outcome(exitCode: 0, output: "OK\n") == .renewed)
        #expect(ClaudeCLI.outcome(exitCode: 1, output: "Not logged in · Please run /login") == .notLoggedIn)
        #expect(ClaudeCLI.outcome(exitCode: 0, output: "Not logged in · Please run /login") == .notLoggedIn)
        #expect(ClaudeCLI.outcome(exitCode: 2, output: "error") == .failed)
    }
}
