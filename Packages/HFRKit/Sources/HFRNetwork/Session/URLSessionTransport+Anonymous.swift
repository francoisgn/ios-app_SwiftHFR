import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLSessionTransport {
    /// A transport that never sends nor stores cookies, for anonymous prefetch and images.
    ///
    /// Any authenticated topic GET marks the account's flags read (HFR-PROTOCOL §7, E25), so background prefetch must
    /// not go through an `HFRSession`. Image hosts must not receive forum cookies either (E26).
    public static func anonymous() -> URLSessionTransport {
        URLSessionTransport(session: URLSession(configuration: anonymousConfiguration()))
    }

    /// Ephemeral configuration with cookies disabled both ways and no cache or credential store.
    static func anonymousConfiguration(base: URLSessionConfiguration = .ephemeral) -> URLSessionConfiguration {
        base.httpCookieStorage = nil
        base.httpShouldSetCookies = false
        base.httpCookieAcceptPolicy = .never
        base.urlCache = nil
        base.urlCredentialStorage = nil
        return base
    }
}
