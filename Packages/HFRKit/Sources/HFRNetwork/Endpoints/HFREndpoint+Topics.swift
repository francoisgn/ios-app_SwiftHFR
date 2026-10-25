import Foundation
import HFRModels

extension HFREndpoint {
    /// R2: the topic list of a forum (`ObjCForumTopicsLoaderWorker.m:36-89, 128-141`).
    ///
    /// The query is exactly `config, cat, page, subcat (empty), owntopic`. Private messages use `privateMessages(page:)`.
    public static func topicList(category: CategoryID, filter: TopicListFilter = .all, page: Int = 1) throws -> HTTPRequest {
        try requirePage(page)
        guard let path = ForumCatalogue.topicListPath(categoryID: category, filter: filter, page: page) else {
            throw NetworkError.invalidRequest(reason: "private messages have their own list")
        }
        return try .get(url(path: path))
    }

    /// R5: one page of a topic (`ObjCTopicPageWorker.m:14-43, 86-94`).
    ///
    /// With a `slug` and a category present in `ForumCatalogue`, builds the canonical
    /// `/hfr/<forum>/<slug>-sujet_<post>_<page>.htm` (HFR-PROTOCOL §6). Otherwise, or when the slug is not made of
    /// unreserved characters, builds `forum2.php?config=hfr.inc&cat=..&post=..&page=..`, which HFR redirects (301)
    /// to the canonical form. Redirects are followed, so the response's final URL tells the page.
    /// `anchor` is the message number (`numreponse`), added as the `#t<number>` fragment.
    public static func topicPage(topic: TopicID, page: Int = 1, slug: String? = nil, anchor: Int? = nil) throws -> HTTPRequest {
        try requirePage(page)
        var request: HTTPRequest
        if let slug, QueryEncoding.isPathSafe(slug), let forum = forumSegment(of: topic.category) {
            request = try .get(url(path: "/hfr/\(forum)/\(slug)-sujet_\(topic.topic)_\(page).htm"))
        } else {
            request = try .get(url(path: "/forum2.php", query: [
                ("config", config), ("cat", topic.category.queryValue), ("post", String(topic.topic)), ("page", String(page))
            ]))
        }
        if let anchor, let withFragment = URL(string: request.url.absoluteString + "#t\(anchor)") {
            request.url = withFragment
        }
        return request
    }

    /// R5 for a known message: the page holding it, with its `#t<numreponse>` anchor.
    public static func topicPage(post: PostID, page: Int, slug: String? = nil) throws -> HTTPRequest {
        try topicPage(topic: post.topic, page: page, slug: slug, anchor: post.numreponse)
    }

    /// The forum's path segment (`Discussions` in `/hfr/Discussions/liste_sujet-1.htm`), nil when the catalogue lacks it.
    private static func forumSegment(of category: CategoryID) -> String? {
        guard let path = ForumCatalogue.forumPath(for: category) else { return nil }
        let parts = path.split(separator: "/")
        guard parts.count >= 3, parts[0] == "hfr" else { return nil }
        return String(parts[1])
    }
}
