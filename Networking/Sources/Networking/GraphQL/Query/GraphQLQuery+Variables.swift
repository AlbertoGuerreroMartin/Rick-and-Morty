import Foundation

struct DeclaredProperty {
    let propertyIdentifier: String
    let propertyType: Any.Type
    let isOptional: Bool
}

extension GraphQLQuery {
    func declaredProperties() -> [DeclaredProperty] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label else { return nil }
            let mirror = Mirror(reflecting: child.value)
            guard mirror.displayStyle == .optional else {
                return DeclaredProperty(propertyIdentifier: label,
                                        propertyType: declaredType(of: child.value),
                                        isOptional: false)
            }
            guard let wrapped = mirror.children.first?.value else { return nil }
            return DeclaredProperty(propertyIdentifier: label,
                                    propertyType: declaredType(of: wrapped),
                                    isOptional: true)
        }
    }
    
    func queryParametersDefinitions(_ declaredProperties: [DeclaredProperty]) -> String {
        return declaredProperties.map {
            // "id" keys must be defined on the query document as an "ID!" type,
            // which doesn't exists on Swift, so it's manually parsed here.
            let type = $0.propertyIdentifier == "id" ? "ID" : "\($0.propertyType)"
            // An ! mark must be added to the type if it isn't optional, to match GraphQL requirements.
            return "$\($0.propertyIdentifier): \(type)\($0.isOptional ? "" : "!")"
        }.joined(separator: ", ")
    }

    /// The type the server expects for `value`.
    ///
    /// A `RawRepresentable` — typically a `String`-backed enum used to constrain a
    /// filter — has no counterpart in the schema, so it's the raw value that goes
    /// over the wire (`Encodable` synthesis serialises it that way too). Unwrapping
    /// is repeated in case the raw value is itself `RawRepresentable`.
    private func declaredType(of value: Any) -> Any.Type {
        var value = value
        while let rawRepresentable = value as? any RawRepresentable {
            value = rawRepresentable.rawValue
        }
        return type(of: value)
    }
}

extension GraphQLQuery {
    /// The variables this operation will send, pretty-printed. Used by the in-app
    /// query inspector so you can see exactly what goes over the wire.
    var variablesJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }
}
