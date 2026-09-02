import Foundation

extension GraphQLQuery {
    public var document: String {
        let declaredProperties = declaredProperties()
        let arguments = declaredProperties
            .map { "\($0.propertyIdentifier): $\($0.propertyIdentifier)" }
            .joined(separator: ", ")

        return GraphQLOperation.document(
            rootField: Self.objectRequested,
            variableDefinitions: queryParametersDefinitions(declaredProperties),
            arguments: arguments,
            selection: ResponseEntity.document
        )
    }
}
