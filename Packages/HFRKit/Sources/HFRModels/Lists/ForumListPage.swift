/// The parsed home page: forum categories plus the session facts the page exposes.
public struct ForumListPage: Sendable, Hashable {
    /// Categories in page order (all of them: hiding some is an app policy).
    public var forums: [ForumCategory]
    /// Whether the page shows a logged-in session.
    public var isLoggedIn: Bool
    /// Unread private messages announced by the page header.
    public var unreadPrivateMessages: Int?
    /// The `hash_check` token of the page (a secret: never log it); nil when logged out.
    public var hashCheck: String?

    /// Creates a forum list page.
    public init(forums: [ForumCategory], isLoggedIn: Bool = false, unreadPrivateMessages: Int? = nil, hashCheck: String? = nil) {
        self.forums = forums
        self.isLoggedIn = isLoggedIn
        self.unreadPrivateMessages = unreadPrivateMessages
        self.hashCheck = hashCheck
    }
}
