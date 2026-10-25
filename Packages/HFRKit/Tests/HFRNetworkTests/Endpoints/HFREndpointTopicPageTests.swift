import HFRModels
import Testing
@testable import HFRNetwork

struct HFREndpointTopicPageTests {
    private static let host = "https://forum.hardware.fr"

    @Test(arguments: [
        // Slug known and forum in the catalogue: canonical URL.
        (CategoryID.forum(13), 1711, 450, "mon-sujet" as String?,
         "/hfr/Discussions/mon-sujet-sujet_1711_450.htm"),
        (CategoryID.forum(1), 7, 1, "carte-graphique",
         "/hfr/Hardware/carte-graphique-sujet_7_1.htm"),
        (CategoryID.forum(32), 99, 3, "ia_et.co~x",
         "/hfr/ia/ia_et.co~x-sujet_99_3.htm"),
        // No slug: forum2.php, which redirects.
        (CategoryID.forum(13), 1711, 450, nil,
         "/forum2.php?config=hfr.inc&cat=13&post=1711&page=450"),
        // Empty or unsafe slug: forum2.php.
        (CategoryID.forum(13), 5, 2, "",
         "/forum2.php?config=hfr.inc&cat=13&post=5&page=2"),
        (CategoryID.forum(13), 5, 2, "a/b",
         "/forum2.php?config=hfr.inc&cat=13&post=5&page=2"),
        (CategoryID.forum(13), 5, 2, "été",
         "/forum2.php?config=hfr.inc&cat=13&post=5&page=2"),
        // Category absent from the catalogue (forum 99) or private: forum2.php.
        (CategoryID.forum(99), 5, 2, "x",
         "/forum2.php?config=hfr.inc&cat=99&post=5&page=2"),
        (CategoryID.privateMessages, 8, 1, "x",
         "/forum2.php?config=hfr.inc&cat=prive&post=8&page=1")
    ])
    func topicPage(category: CategoryID, post: Int, page: Int, slug: String?, expected: String) throws {
        let request = try HFREndpoint.topicPage(topic: TopicID(category: category, topic: post), page: page, slug: slug)
        #expect(request.url.absoluteString == Self.host + expected)
        #expect(request.method == .get)
        #expect(request.redirectPolicy == .follow)
    }

    @Test func pageDefaultsToOne() throws {
        let request = try HFREndpoint.topicPage(topic: TopicID(category: .forum(13), topic: 42))
        #expect(request.url.absoluteString == "\(Self.host)/forum2.php?config=hfr.inc&cat=13&post=42&page=1")
    }

    @Test func pageBelowOneIsRefused() {
        let topic = TopicID(category: .forum(13), topic: 42)
        #expect(throws: NetworkError.self) { try HFREndpoint.topicPage(topic: topic, page: 0) }
        #expect(throws: NetworkError.self) { try HFREndpoint.topicPage(topic: topic, page: -1, slug: "x") }
    }

    @Test func anchorBecomesFragmentOnBothShapes() throws {
        let topic = TopicID(category: .forum(13), topic: 42)
        let plain = try HFREndpoint.topicPage(topic: topic, page: 2, anchor: 555)
        #expect(plain.url.absoluteString == "\(Self.host)/forum2.php?config=hfr.inc&cat=13&post=42&page=2#t555")
        let canonical = try HFREndpoint.topicPage(topic: topic, page: 2, slug: "s", anchor: 555)
        #expect(canonical.url.absoluteString == "\(Self.host)/hfr/Discussions/s-sujet_42_2.htm#t555")
    }

    @Test func postIDCarriesItsAnchor() throws {
        let post = PostID(topic: TopicID(category: .forum(13), topic: 42), numreponse: 1234)
        let request = try HFREndpoint.topicPage(post: post, page: 3)
        #expect(request.url.absoluteString == "\(Self.host)/forum2.php?config=hfr.inc&cat=13&post=42&page=3#t1234")
    }

    @Test func everyCatalogueForumHasACanonicalShape() throws {
        for entry in ForumCatalogue.entries where !entry.path.hasPrefix("https:") {
            let topic = TopicID(category: entry.categoryID, topic: 1)
            let segment = entry.path.split(separator: "/")[1]
            let request = try HFREndpoint.topicPage(topic: topic, page: 1, slug: "s")
            #expect(request.url.absoluteString == "\(Self.host)/hfr/\(segment)/s-sujet_1_1.htm")
        }
    }
}
