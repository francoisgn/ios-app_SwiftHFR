import Foundation

/// A coding key for objects whose keys are not known in advance.
struct DynamicKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ string: String) { stringValue = string }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension KeyedDecodingContainer where Key == DynamicKey {
    /// Every key not in `known`, with its raw JSON value: what a round trip must not lose.
    func decodeRemainingKeys(excluding known: Set<String>) throws -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for key in allKeys where !known.contains(key.stringValue) {
            result[key.stringValue] = try decode(JSONValue.self, forKey: key)
        }
        return result
    }
}

extension KeyedEncodingContainer where Key == DynamicKey {
    /// Writes preserved keys; a preserved key never overrides a modelled one.
    mutating func encodeRemainingKeys(_ extra: [String: JSONValue], excluding known: Set<String>) throws {
        for (name, value) in extra.sorted(by: { $0.key < $1.key }) where !known.contains(name) {
            try encode(value, forKey: DynamicKey(name))
        }
    }
}

/// The MPStorage wire formats are loosely typed (other clients write numbers as strings and the reverse).
extension KeyedDecodingContainer {
    /// Reads an integer written as a number, a whole decimal or a numeric string.
    func decodeLenientInt(forKey key: Key) throws -> Int {
        if let value = try decodeLenientIntIfPresent(forKey: key) { return value }
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing integer"))
    }

    /// Like `decodeLenientInt`, nil when the key is absent or null.
    func decodeLenientIntIfPresent(forKey key: Key) throws -> Int? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Double.self, forKey: key), value.rounded() == value, abs(value) < 9e15 {
            return Int(value)
        }
        if let text = try? decode(String.self, forKey: key), let value = Int(text.trimmingCharacters(in: .whitespaces)) {
            return value
        }
        throw DecodingError.typeMismatch(Int.self, .init(codingPath: codingPath + [key], debugDescription: "Not an integer"))
    }

    /// Reads a string written as a string or a number.
    func decodeLenientStringIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        throw DecodingError.typeMismatch(String.self, .init(codingPath: codingPath + [key], debugDescription: "Not a string"))
    }

    /// Reads a millisecond timestamp (number or numeric string) as a `Date`.
    func decodeMillisecondDateIfPresent(forKey key: Key) throws -> Date? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Double.self, forKey: key) { return Date(timeIntervalSince1970: value / 1000) }
        if let text = try? decode(String.self, forKey: key), let value = Double(text) {
            return Date(timeIntervalSince1970: value / 1000)
        }
        throw DecodingError.typeMismatch(Date.self, .init(codingPath: codingPath + [key], debugDescription: "Not a timestamp"))
    }
}

extension KeyedEncodingContainer {
    /// Writes a `Date` as integer milliseconds since 1970, as every MPStorage writer does.
    mutating func encodeMilliseconds(_ date: Date?, forKey key: Key) throws {
        guard let date else { return }
        try encode(Int64((date.timeIntervalSince1970 * 1000).rounded()), forKey: key)
    }
}
