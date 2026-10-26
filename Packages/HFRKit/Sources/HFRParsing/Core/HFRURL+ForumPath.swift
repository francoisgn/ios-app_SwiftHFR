import Foundation

extension HFRURL {
    /// Forum-relative form (`/path?query#fragment`) of a link read from a page, or nil when it must not be followed.
    ///
    /// List models keep relative paths (LOT-010), and the app requests them with the account session, so every path
    /// a list parser emits goes through here (LESSONS 37): a path starting with a single `/` is kept as is; anything else
    /// is resolved by `absolute(_:relativeTo:)` and kept only when it is `https` on `forum.hardware.fr` without user info
    /// or a port other than 443. `&amp;` is decoded; an empty link, `javascript:`, another host, a protocol-relative
    /// `//host` or `/\host` link, and `http://forum.hardware.fr:80/` give nil.
    static func forumRelativePath(_ raw: String) -> String? {
        let link = decodingAmpersands(String(raw.trimmingHTMLWhitespace))
        guard !link.isEmpty, !link.unicodeScalars.contains(where: { $0.properties.generalCategory == .control }) else {
            return nil
        }
        if link.hasPrefix("/") {
            let second = link.dropFirst().first
            return second == "/" || second == "\\" ? nil : link
        }
        guard
            let url = absolute(link),
            url.scheme == "https",
            url.host(percentEncoded: false) == forumHost,
            url.port == nil || url.port == 443,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        else { return nil }
        var path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        if let query = components.percentEncodedQuery {
            path += "?" + query
        }
        if let fragment = components.percentEncodedFragment {
            path += "#" + fragment
        }
        return path
    }
}
