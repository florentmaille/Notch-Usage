import Foundation
import Testing
@testable import NotchUsageCore

@Suite("Support : redirections, instance unique, conversions bornées")
struct SupportTests {
    func url(_ s: String) -> URL { URL(string: s)! }

    /// Les requêtes portent le jeton ou le cookie de session : une redirection ne se suit que vers le même hôte, en HTTPS.
    @Test func redirectsStayOnTheSameHostOverHTTPS() {
        let usage = url("https://claude.ai/api/organizations/x/usage")
        #expect(RedirectPolicy.allows(from: usage, to: url("https://claude.ai/api/organizations/x/usage/")))
        #expect(RedirectPolicy.allows(from: usage, to: url("https://CLAUDE.AI/login")))
        #expect(!RedirectPolicy.allows(from: usage, to: url("https://evil.example/collect")))
        #expect(!RedirectPolicy.allows(from: usage, to: url("https://www.claude.ai/login")))
        #expect(!RedirectPolicy.allows(from: usage, to: url("http://claude.ai/api/organizations")))
        #expect(!RedirectPolicy.allows(from: usage, to: nil))
        #expect(!RedirectPolicy.allows(from: nil, to: usage))
    }

    /// Deux copies lancées : la plus récente cède ; au même instant, le plus grand pid cède. Jamais les deux.
    @Test func theNewerInstanceYields() {
        let t = Date(timeIntervalSince1970: 1_762_000_000)
        let old = SingleInstance.Process(pid: 900, launchedAt: t), new = SingleInstance.Process(pid: 300, launchedAt: t.addingTimeInterval(5))
        #expect(SingleInstance.shouldYield(me: new, others: [old, new]))
        #expect(!SingleInstance.shouldYield(me: old, others: [old, new]))
        #expect(!SingleInstance.shouldYield(me: old, others: [old]))
        #expect(!SingleInstance.shouldYield(me: old, others: []))
        // Même instant, ou dates inconnues : le plus petit pid reste, l'autre cède.
        let a = SingleInstance.Process(pid: 10, launchedAt: t), b = SingleInstance.Process(pid: 20, launchedAt: t)
        #expect(!SingleInstance.shouldYield(me: a, others: [b]) && SingleInstance.shouldYield(me: b, others: [a]))
        let c = SingleInstance.Process(pid: 10, launchedAt: nil), d = SingleInstance.Process(pid: 20, launchedAt: nil)
        #expect(!SingleInstance.shouldYield(me: c, others: [d]) && SingleInstance.shouldYield(me: d, others: [c]))
    }

    @Test func boundedIntNeverTraps() {
        #expect(1e300.boundedInt == 1_000_000_000_000 && (-1e300).boundedInt == -1_000_000_000_000)
        #expect(Double.nan.boundedInt == 0 && Double.infinity.boundedInt == 0)
        #expect(41.9.boundedInt == 41)
    }
}
