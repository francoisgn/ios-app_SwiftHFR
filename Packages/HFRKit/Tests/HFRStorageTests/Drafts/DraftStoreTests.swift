import Foundation
import HFRModels
import Synchronization
import Testing
@testable import HFRStorage

/// A clock the tests move by hand.
private final class TestClock: Sendable {
    private let current: Mutex<Date>
    init(_ start: Date) { current = Mutex(start) }
    var now: Date { current.withLock { $0 } }
    func advance(days: Double) { current.withLock { $0 = $0.addingTimeInterval(days * 86_400) } }
}

@Suite struct DraftStoreTests {
    private let topic = TopicID(category: .forum(13), topic: 4242)
    private let start = Date(timeIntervalSince1970: 1_761_000_000)

    private func makeStore(
        timeToLive: TimeInterval = 10 * 86_400,
        maximumCount: Int = 100
    ) -> (DraftStore, InMemoryDraftPersistence, TestClock) {
        let persistence = InMemoryDraftPersistence()
        let clock = TestClock(start)
        let store = DraftStore(persistence: persistence, timeToLive: timeToLive, maximumCount: maximumCount, clock: { clock.now })
        return (store, persistence, clock)
    }

    @Test func savedDraftComesBackWithItsSubject() async throws {
        let (store, _, _) = makeStore()
        try await store.save("Bonjour", subject: "Titre", for: .newTopic(forum: .forum(13)), account: "me")
        let draft = await store.draft(for: .newTopic(forum: .forum(13)), account: "me")
        #expect(draft?.text == "Bonjour")
        #expect(draft?.subject == "Titre")
        #expect(draft?.updatedAt == start)
    }

    @Test func contextsAreIsolated() async throws {
        let (store, _, _) = makeStore()
        try await store.save("reply p1", for: .reply(topic: topic, page: 1), account: "me")
        try await store.save("reply p2", for: .reply(topic: topic, page: 2), account: "me")
        try await store.save("edit", for: .edit(topic: topic, post: 5), account: "me")
        try await store.save("mp", for: .privateMessage(recipient: "Marc"), account: "me")
        try await store.save("topic", for: .newTopic(forum: .forum(13)), account: "me")
        #expect(await store.draft(for: .reply(topic: topic, page: 1), account: "me")?.text == "reply p1")
        #expect(await store.draft(for: .reply(topic: topic, page: 2), account: "me")?.text == "reply p2")
        #expect(await store.draft(for: .edit(topic: topic, post: 5), account: "me")?.text == "edit")
        #expect(await store.draft(for: .privateMessage(recipient: "marc"), account: "me")?.text == "mp")
        #expect(await store.draft(for: .newTopic(forum: .forum(14)), account: "me") == nil)
        #expect(await store.drafts(account: "me").count == 5)
    }

    @Test func draftsAreScopedPerAccount() async throws {
        let (store, _, _) = makeStore()
        try await store.save("mine", for: .reply(topic: topic, page: 1), account: "Alice")
        #expect(await store.draft(for: .reply(topic: topic, page: 1), account: "alice")?.text == "mine")
        #expect(await store.draft(for: .reply(topic: topic, page: 1), account: "bob") == nil)
    }

    @Test func savingAgainReplacesInsteadOfDuplicating() async throws {
        let (store, persistence, _) = makeStore()
        try await store.save("one", for: .legacyGlobal, account: "me")
        try await store.save("two", for: .legacyGlobal, account: "me")
        #expect(persistence.document?.drafts.map(\.text) == ["two"])
    }

    @Test func savingEmptyContentRemovesTheDraftAndSkipsTheWriteWhenThereIsNone() async throws {
        let (store, persistence, _) = makeStore()
        try await store.save("", for: .legacyGlobal, account: "me")
        #expect(persistence.document == nil)
        try await store.save("text", for: .legacyGlobal, account: "me")
        try await store.save("", subject: "", for: .legacyGlobal, account: "me")
        #expect(await store.draft(for: .legacyGlobal, account: "me") == nil)
        #expect(persistence.document?.drafts.isEmpty == true)
    }

    @Test func aSubjectAloneIsADraft() async throws {
        let (store, _, _) = makeStore()
        try await store.save("", subject: "Idée", for: .newTopic(forum: .forum(13)), account: "me")
        #expect(await store.draft(for: .newTopic(forum: .forum(13)), account: "me")?.subject == "Idée")
    }

    @Test func discardRemovesOnlyThatDraft() async throws {
        let (store, _, _) = makeStore()
        try await store.save("a", for: .reply(topic: topic, page: 1), account: "me")
        try await store.save("b", for: .newTopic(forum: .forum(13)), account: "me")
        #expect(try await store.discard(for: .reply(topic: topic, page: 1), account: "me"))
        #expect(try await !store.discard(for: .reply(topic: topic, page: 1), account: "me"))
        #expect(await store.draft(for: .newTopic(forum: .forum(13)), account: "me")?.text == "b")
    }

    @Test func discardAllClearsOneAccountOnly() async throws {
        let (store, _, _) = makeStore()
        try await store.save("a", for: .legacyGlobal, account: "me")
        try await store.save("b", for: .newTopic(forum: .forum(13)), account: "ME")
        try await store.save("c", for: .legacyGlobal, account: "other")
        #expect(try await store.discardAll(account: "me") == 2)
        #expect(await store.drafts(account: "me").isEmpty)
        #expect(await store.drafts(account: "other").count == 1)
    }

    @Test func expiredDraftsAreInvisibleThenPurged() async throws {
        let (store, persistence, clock) = makeStore(timeToLive: 10 * 86_400)
        try await store.save("old", for: .legacyGlobal, account: "me")
        clock.advance(days: 5)
        try await store.save("newer", for: .newTopic(forum: .forum(13)), account: "me")
        clock.advance(days: 6)
        #expect(await store.draft(for: .legacyGlobal, account: "me") == nil)
        #expect(await store.draft(for: .newTopic(forum: .forum(13)), account: "me")?.text == "newer")
        #expect(persistence.document?.drafts.count == 2)
        #expect(try await store.purgeExpired() == 1)
        #expect(persistence.document?.drafts.map(\.text) == ["newer"])
        #expect(try await store.purgeExpired() == 0)
    }

    @Test func draftExactlyAtTheTimeToLiveIsStillLive() async throws {
        let (store, _, clock) = makeStore(timeToLive: 10 * 86_400)
        try await store.save("edge", for: .legacyGlobal, account: "me")
        clock.advance(days: 10)
        #expect(await store.draft(for: .legacyGlobal, account: "me") != nil)
        clock.advance(days: 0.001)
        #expect(await store.draft(for: .legacyGlobal, account: "me") == nil)
    }

    @Test func savingPurgesExpiredDraftsFromTheFile() async throws {
        let (store, persistence, clock) = makeStore(timeToLive: 10 * 86_400)
        try await store.save("old", for: .legacyGlobal, account: "me")
        clock.advance(days: 11)
        try await store.save("fresh", for: .newTopic(forum: .forum(13)), account: "me")
        #expect(persistence.document?.drafts.map(\.text) == ["fresh"])
    }

    @Test func theCountIsBoundedKeepingTheMostRecent() async throws {
        let (store, persistence, clock) = makeStore(maximumCount: 3)
        for index in 1...5 {
            try await store.save("d\(index)", for: .edit(topic: topic, post: index), account: "me")
            clock.advance(days: 0.01)
        }
        #expect(Set(persistence.document?.drafts.map(\.text) ?? []) == ["d3", "d4", "d5"])
    }

    @Test func draftsListIsNewestFirst() async throws {
        let (store, _, clock) = makeStore()
        try await store.save("first", for: .edit(topic: topic, post: 1), account: "me")
        clock.advance(days: 1)
        try await store.save("second", for: .edit(topic: topic, post: 2), account: "me")
        #expect(await store.drafts(account: "me").map(\.text) == ["second", "first"])
    }

    @Test func survivesANewStoreOverTheSamePersistence() async throws {
        let (store, persistence, clock) = makeStore()
        try await store.save("kept", subject: "S", for: .privateMessage(recipient: "Marc"), account: "me")
        let reopened = DraftStore(persistence: persistence, clock: { clock.now })
        #expect(await reopened.draft(for: .privateMessage(recipient: "MARC"), account: "me")?.text == "kept")
    }

    @Test func concurrentSavesAreAllKept() async throws {
        let (store, persistence, _) = makeStore()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<30 {
                group.addTask { try await store.save("t\(index)", for: .edit(topic: topic, post: index), account: "me") }
            }
            try await group.waitForAll()
        }
        #expect(persistence.document?.drafts.count == 30)
    }
}
