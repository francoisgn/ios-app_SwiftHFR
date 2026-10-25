import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HFRModels
import Testing
@testable import HFRNetwork

struct StoredCookieConversionTests {
    private let expiry = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func roundTripKeepsEveryPersistedField() throws {
        let stored = StoredCookie(
            name: "md_user", value: "fake%20pseudo", domain: ".hardware.fr", path: "/",
            expiresDate: expiry, isSecure: true, isHTTPOnly: true
        )
        let cookie = try #require(stored.makeHTTPCookie())
        #expect(cookie.domain == ".hardware.fr")
        #expect(cookie.isSecure)
        #expect(cookie.isHTTPOnly)
        #expect(cookie.expiresDate == expiry)
        #expect(StoredCookie(cookie) == stored)
    }

    @Test func sessionCookieWithoutFlagsRoundTrips() throws {
        let stored = StoredCookie(name: "sid", value: "x", domain: "forum.hardware.fr", path: "/forum")
        let cookie = try #require(stored.makeHTTPCookie())
        #expect(cookie.expiresDate == nil)
        #expect(!cookie.isSecure)
        #expect(!cookie.isHTTPOnly)
        #expect(StoredCookie(cookie) == stored)
    }

    @Test func setCookieHeaderAttributesSurvive() throws {
        let url = try #require(URL(string: "https://forum.hardware.fr/login_validation.php"))
        let header = "md_user=fake; expires=Wed, 01-Jan-2031 00:00:00 GMT; path=/; domain=.hardware.fr; secure; HttpOnly"
        let cookie = try #require(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": header], for: url).first)
        let stored = try #require(StoredCookie(cookie))
        #expect(stored.domain == ".hardware.fr")
        #expect(stored.isSecure && stored.isHTTPOnly)
        #expect(stored.expiresDate == Date(timeIntervalSince1970: 1_924_992_000))
        #expect(StoredCookie(try #require(stored.makeHTTPCookie())) == stored)
    }

    @Test func emptyNameOrDomainIsRejected() {
        #expect(StoredCookie(name: "", value: "v", domain: ".hardware.fr").makeHTTPCookie() == nil)
        #expect(StoredCookie(name: "n", value: "v", domain: "").makeHTTPCookie() == nil)
    }

    @Test func expiryIsInclusive() {
        let cookie = StoredCookie(name: "n", value: "v", domain: ".hardware.fr", expiresDate: expiry)
        #expect(!cookie.isExpired(at: expiry.addingTimeInterval(-1)))
        #expect(cookie.isExpired(at: expiry))
        #expect(!StoredCookie(name: "n", value: "v", domain: ".hardware.fr").isExpired(at: .distantFuture))
    }
}
