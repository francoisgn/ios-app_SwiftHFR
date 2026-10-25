import Foundation

/// Encodes then decodes a value, so tests exercise the exact persisted representation.
func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
    let data = try JSONEncoder().encode(value)
    return try JSONDecoder().decode(Value.self, from: data)
}
