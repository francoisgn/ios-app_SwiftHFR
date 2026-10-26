import Foundation
import Testing
@testable import HFRModels

@Suite struct MPStorageCodecTests {
    private typealias Fixtures = MPStorageFixtures

    @Test func writtenTextDecodesToTheSameDocumentWithEveryNamespace() throws {
        let document = try Fixtures.document()
        let text = try MPStorageCodec.encodeForWriting(document)
        #expect(try MPStorageCodec.decode(text) == document)
        for key in ["hfrChat", "superFavs", "futureRootKey", #""active":true"#, #""color":"red""#] {
            #expect(text.contains(key))
        }
    }

    @Test func outputIsCompactWithIntegersAndUnescapedSlashes() throws {
        let text = try MPStorageCodec.encodeForWriting(try Fixtures.document())
        #expect(!text.contains("\n") && !text.contains(": "))
        #expect(text.contains(#""x":[1,2,{"y":null}]"#))
        #expect(text.contains(#""href":"/h""#))
        #expect(text.contains(#""createDate":1700000000123"#))
    }

    @Test func nonBMPCharactersAnywhereAreRefusedWithTheirPath() throws {
        var document = try Fixtures.document()
        document.primary.extra["hfrChat"] = .object(["msg": .array([.string("ok"), .string("🎉")])])
        let error = try #require(throws: MPStorageError.self) { try MPStorageCodec.encodeForWriting(document) }
        #expect(error == .nonBMPCharacter(path: ".data[0].hfrChat.msg[1]", codePoint: 0x1F389))
    }

    @Test func aNonBMPKeyIsRefusedToo() throws {
        var document = try Fixtures.document()
        document.extra["🔑"] = .null
        let error = try #require(throws: MPStorageError.self) { try MPStorageCodec.encodeForWriting(document) }
        #expect(error == .nonBMPCharacter(path: ".<key>", codePoint: 0x1F511))
    }

    @Test func theSizeCapIsInclusive() throws {
        let document = try Fixtures.document()
        let size = try MPStorageCodec.encodeForWriting(document).utf8.count
        #expect(throws: Never.self) { try MPStorageCodec.encodeForWriting(document, limit: size) }
        #expect(throws: MPStorageError.tooLarge(byteCount: size, limit: size - 1)) {
            try MPStorageCodec.encodeForWriting(document, limit: size - 1)
        }
    }

    @Test func aDocumentAbove64KiBIsRefused() throws {
        var document = MPStorageDocument()
        for index in 0..<700 {
            let label = String(repeating: "x", count: 80)
            try document.addBookmark(Fixtures.bookmark(index, label: label), stamp: Fixtures.stamp(1_800_000_000))
        }
        let error = try #require(throws: MPStorageError.self) { try MPStorageCodec.encodeForWriting(document) }
        guard case let .tooLarge(byteCount, limit) = error else {
            Issue.record("Unexpected \(error)")
            return
        }
        #expect(limit == 65_536 && byteCount > limit)
    }

    @Test func aDocumentWithoutAVersion01EntryIsNeverWritten() throws {
        let document = try Fixtures.document(#"{"data":[{"version":"0.2"}]}"#)
        #expect(throws: MPStorageError.noWritableEntry) { try MPStorageCodec.encodeForWriting(document) }
    }

    @Test(arguments: ["", "{}", #"{"data":"#, "not json"])
    func invalidTextThrowsInsteadOfResetting(text: String) {
        #expect(throws: (any Error).self) { try MPStorageCodec.decode(text) }
    }

    @Test func tombstonesRoundTripAndForeignValuesStayVerbatim() throws {
        let json = """
        {"data":[{"version":"0.1",
          "bookmarks":{"list":[],"tombstones":[{"id":"13-1-2","deleteDate":1800000000000,"by":"x"}]},
          "blacklist":{"list":[],"tombstones":[{"nope":1}]}}]}
        """
        let document = try Fixtures.document(json)
        #expect(document.primary.bookmarks?.tombstones.first?.id == "13-1-2")
        #expect(document.primary.bookmarks?.tombstones.first?.extra["by"] == .string("x"))
        #expect(document.primary.blocklist?.tombstones.isEmpty == true)
        #expect(document.primary.blocklist?.extra["tombstones"] == .array([.object(["nope": .number(1)])]))
        let text = try MPStorageCodec.encodeForWriting(document)
        #expect(try MPStorageCodec.decode(text) == document)
        #expect(text.contains(#""tombstones":[{"nope":1}]"#))
    }
}
