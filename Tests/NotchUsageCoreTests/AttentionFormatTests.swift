import Foundation
import Testing
@testable import NotchUsageCore

@Suite("AttentionFormat (017)")
struct AttentionFormatTests {
    let t0 = Date.iso("2026-11-05T17:00:00Z")

    @Test func arrivalLabelShowsFourSeconds() {
        #expect(AttentionFormat.showsArrival(arrivedAt: t0, now: t0))
        #expect(AttentionFormat.showsArrival(arrivedAt: t0, now: t0.addingTimeInterval(3.9)))
        #expect(!AttentionFormat.showsArrival(arrivedAt: t0, now: t0.addingTimeInterval(4)))
        #expect(!AttentionFormat.showsArrival(arrivedAt: t0.addingTimeInterval(10), now: t0))   // horloge en avance : jamais
    }

    @Test func englishWords() {
        let s = ClaudeStrings.english
        #expect(s.arrival(.approval) == "Approval" && s.arrival(.question) == "Question" && s.arrival(.done) == "Done")
        #expect(s.rowLabel(.approval) == "approval needed" && s.rowLabel(.done) == "finished")
        #expect(s.waitingAnnouncement(1) == "1 Claude session is waiting: " && s.waitingAnnouncement(2) == "2 Claude sessions are waiting: ")
    }

    @Test func countHidesSingletonsAndCapsAtNinePlus() {
        #expect(AttentionFormat.count(0) == "" && AttentionFormat.count(1) == "")
        #expect(AttentionFormat.count(2) == "2" && AttentionFormat.count(9) == "9")
        #expect(AttentionFormat.count(10) == "9+" && AttentionFormat.count(37) == "9+")
    }

    @Test func sinceReadsLikeAnAge() {
        #expect(AttentionFormat.since(t0, now: t0.addingTimeInterval(45), language: .english) == "45 s")
        #expect(AttentionFormat.since(t0, now: t0.addingTimeInterval(2 * 60 + 10), language: .french) == "2 min")
        #expect(AttentionFormat.since(t0, now: t0.addingTimeInterval(70 * 60), language: .english) == "1h 10m")
        #expect(AttentionFormat.since(t0, now: t0.addingTimeInterval(70 * 60), language: .french) == "1 h 10")
        #expect(AttentionFormat.since(t0, now: t0.addingTimeInterval(2 * 3600), language: .french) == "2 h")
        #expect(AttentionFormat.since(t0.addingTimeInterval(5), now: t0, language: .english) == "0 s")
    }

    /// Heure d'événement aberrante : la durée ne fait pas planter la conversion en secondes.
    @Test func absurdEventTimesDoNotTrap() {
        let now = Date(timeIntervalSince1970: 1_762_000_000)
        #expect(AttentionFormat.since(Date(timeIntervalSince1970: 1e300), now: now, language: .english) == "0 s")
        #expect(!AttentionFormat.since(Date(timeIntervalSince1970: -1e300), now: now, language: .french).isEmpty)
    }
}
