import Foundation

/// A parsed topic page (one page of a topic or private conversation).
public struct TopicPage: Sendable, Hashable, Codable {
    /// Category and topic numbers, from the quick-answer form or the URL; nil when neither is available.
    public var topicID: TopicID?
    /// Topic title.
    public var title: String
    /// Page shown (1-based; the initializer raises values below 1 to 1).
    public var currentPage: Int
    /// Number of pages (the initializer raises values below 1 to 1).
    public var maxPage: Int
    /// Page that holds the answer form (absent on closed topics).
    public var answerFormURL: URL?
    /// Hidden inputs of the quick-answer form (`cat`, `post`, `p`, `hash_check`...); contains a secret, never log it.
    public var answerFormFields: [String: String]
    /// True when the page has a `nonlu` link, which the legacy app took as "cannot be favourited".
    public var isUnreadable: Bool
    /// Poll of the topic, if any.
    public var poll: Poll?
    /// Inputs of the in-topic search form (`hash_check`, `word`, ...); nil when the page has none. Contains a secret.
    public var searchFormFields: [String: String]?
    /// Messages in page order.
    public var messages: [Message]

    /// Creates a topic page; `currentPage` and `maxPage` are raised to at least 1.
    public init(
        topicID: TopicID? = nil,
        title: String,
        currentPage: Int = 1,
        maxPage: Int = 1,
        answerFormURL: URL? = nil,
        answerFormFields: [String: String] = [:],
        isUnreadable: Bool = false,
        poll: Poll? = nil,
        searchFormFields: [String: String]? = nil,
        messages: [Message] = []
    ) {
        self.topicID = topicID
        self.title = title
        self.currentPage = max(1, currentPage)
        self.maxPage = max(1, maxPage)
        self.answerFormURL = answerFormURL
        self.answerFormFields = answerFormFields
        self.isUnreadable = isUnreadable
        self.poll = poll
        self.searchFormFields = searchFormFields
        self.messages = messages
    }

    /// The cross-topic key of a message of this page; nil when the topic is unknown.
    public func postID(of message: Message) -> PostID? {
        topicID.map { PostID(topic: $0, numreponse: message.id) }
    }
}
