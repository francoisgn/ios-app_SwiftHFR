import Foundation
import Testing
@testable import HFRStorage

@Suite struct CacheEvictorTests {
    private let now = Date(timeIntervalSince1970: 1_761_000_000)
    private let day: TimeInterval = 86_400

    @Test func removesFilesOlderThanTheMaximumAgeOnly() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let old = try temp.makeFile("old", in: .avatars, size: 5, age: 26 * day, now: now)
        let recent = try temp.makeFile("recent", in: .avatars, size: 7, age: 24 * day, now: now)
        let report = CacheEvictor.evict(directory: temp.cache.url(for: .avatars), policy: .avatars, now: now)
        #expect(!temp.exists(old))
        #expect(temp.exists(recent))
        #expect(report.removedFileCount == 1)
        #expect(report.removedBytes == 5)
        #expect(report.remainingBytes == 7)
        #expect(report.failures.isEmpty)
    }

    @Test func fileExactlyAtTheMaximumAgeIsKept() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let edge = try temp.makeFile("edge", in: .avatars, age: 25 * day, now: now)
        CacheEvictor.evict(directory: temp.cache.url(for: .avatars), policy: .avatars, now: now)
        #expect(temp.exists(edge))
    }

    @Test func sizeBoundRemovesTheOldestFirstUntilItFits() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let oldest = try temp.makeFile("a", in: .avatars, size: 40, age: 3 * day, now: now)
        let middle = try temp.makeFile("b", in: .avatars, size: 40, age: 2 * day, now: now)
        let newest = try temp.makeFile("c", in: .avatars, size: 40, age: 1 * day, now: now)
        let report = CacheEvictor.evict(
            directory: temp.cache.url(for: .avatars), policy: CacheEvictionPolicy(maximumTotalBytes: 90), now: now
        )
        #expect(!temp.exists(oldest))
        #expect(temp.exists(middle))
        #expect(temp.exists(newest))
        #expect(report.removedFileCount == 1)
        #expect(report.remainingBytes == 80)
    }

    @Test func sizeBoundCountsOnlyWhatAgeRulesLeft() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let expired = try temp.makeFile("expired", in: .avatars, size: 100, age: 10 * day, now: now)
        let kept = try temp.makeFile("kept", in: .avatars, size: 100, age: 1 * day, now: now)
        CacheEvictor.evict(
            directory: temp.cache.url(for: .avatars), policy: CacheEvictionPolicy(maximumAge: 5 * day, maximumTotalBytes: 100), now: now
        )
        #expect(!temp.exists(expired))
        #expect(temp.exists(kept))
    }

    @Test func noPolicyLimitsKeepsEverything() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let file = try temp.makeFile("f", in: .avatars, age: 1000 * day, now: now)
        let report = CacheEvictor.evict(directory: temp.cache.url(for: .avatars), policy: CacheEvictionPolicy(), now: now)
        #expect(temp.exists(file))
        #expect(report.removedFileCount == 0)
    }

    @Test func missingDirectoryIsAnEmptyCache() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let report = CacheEvictor.evict(directory: temp.cache.url(for: .avatars), policy: .avatars, now: now)
        #expect(report == CacheEvictionReport())
    }

    @Test func recursesIntoSubfoldersButNeverRemovesFolders() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let directory = try temp.cache.prepare(.avatars)
        let nested = directory.appending(path: "sub/deeper", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appending(path: "x")
        try Data(count: 3).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-30 * day)], ofItemAtPath: file.path())
        CacheEvictor.evict(directory: directory, policy: .avatars, now: now)
        #expect(!temp.exists(file))
        #expect(temp.exists(nested))
    }

    @Test func symbolicLinksAreNeitherFollowedNorCounted() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let outside = temp.base.appending(path: "outside.bin")
        try Data(count: 500).write(to: outside)
        try FileManager.default.setAttributes([.modificationDate: now.addingTimeInterval(-90 * day)], ofItemAtPath: outside.path())
        let directory = try temp.cache.prepare(.avatars)
        try FileManager.default.createSymbolicLink(at: directory.appending(path: "link"), withDestinationURL: outside)
        let report = CacheEvictor.evict(directory: directory, policy: .avatars, now: now)
        #expect(temp.exists(outside))
        #expect(report.removedFileCount == 0)
        #expect(report.remainingBytes == 0)
    }

    @Test func evictAllAppliesEachAreasOwnPolicy() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let page = try temp.makeFile("p.htm", in: .topicPages, age: 2 * day, now: now)
        let avatar = try temp.makeFile("a", in: .avatars, age: 2 * day, now: now)
        let reports = temp.cache.evictAll(now: now)
        #expect(!temp.exists(page))
        #expect(temp.exists(avatar))
        #expect(reports[.topicPages]?.removedFileCount == 1)
        #expect(reports[.avatars]?.removedFileCount == 0)
    }

    @Test func clearEmptiesAnAreaAndKeepsTheOthers() throws {
        let temp = try TemporaryCache()
        defer { temp.cleanUp() }
        let avatar = try temp.makeFile("a", in: .avatars, size: 4, age: 0, now: .now)
        let page = try temp.makeFile("p", in: .topicPages, size: 6, age: 0, now: .now)
        let report = temp.cache.clear(.avatars)
        #expect(!temp.exists(avatar))
        #expect(temp.exists(page))
        #expect(report.removedBytes == 4)
        #expect(temp.cache.size(of: .avatars) == 0)
        #expect(temp.cache.size(of: .topicPages) == 6)
    }
}
