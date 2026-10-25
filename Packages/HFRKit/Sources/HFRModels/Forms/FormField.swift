/// An `<input>` of a form, as found in the page (decisions about what to send are made later).
public struct FormField: Sendable, Hashable, Codable {
    /// The `name` attribute.
    public var name: String
    /// The `value` attribute, entity-decoded; empty when absent.
    public var value: String
    /// Input type.
    public var kind: FormInputKind
    /// True when a checkbox or radio carries the `checked` attribute.
    public var isChecked: Bool

    /// Creates a field.
    public init(name: String, value: String = "", kind: FormInputKind = .text, isChecked: Bool = false) {
        self.name = name
        self.value = value
        self.kind = kind
        self.isChecked = isChecked
    }
}
