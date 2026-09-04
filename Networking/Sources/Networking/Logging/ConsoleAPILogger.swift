import Foundation
import os

/// Writes every event to the unified logging system, which Xcode shows in its
/// console.
///
/// The text is built by `APILogFormatter` so the format is testable without
/// capturing output; this type only decides *where* the text goes. `os.Logger`
/// rather than `print`, because of how the Xcode console filters: stdout is
/// consumed line by line, so a filter on "API Request" keeps only the first
/// line of each log and drops the headers and body underneath. A unified-log
/// message is one entry no matter how many lines it spans, so the whole log
/// matches or none of it does.
///
/// The message is logged as public. Everything in it is already on the wire
/// and the sink is only ever attached in debug builds; `<private>` in place of
/// the body would defeat the purpose.
public struct ConsoleAPILogger: APILogSinkContract {
    private let formatter: APILogFormatter
    private let logger: Logger

    /// - Parameters:
    ///   - subsystem: the unified-logging subsystem, typically the app's bundle
    ///     identifier, so the entries can be filtered by app in Console.app.
    ///   - category: the unified-logging category, shown as a column in Xcode.
    public init(
        subsystem: String = "Networking",
        category: String = "API",
        timeZone: TimeZone = .current
    ) {
        formatter = APILogFormatter(timeZone: timeZone)
        logger = Logger(subsystem: subsystem, category: category)
    }

    public func log(_ event: APILogEvent) {
        logger.debug("\(formatter.string(for: event), privacy: .public)")
    }
}

/// Turns a log event into the text the console shows.
///
/// ```
/// ♦️ 14:20:37.360 > [PENDING] API Request: [POST] https://rickandmortyapi.com/graphql
/// [Method]: POST
/// [Headers]:
///     Accept: application/json
///     Content-Type: application/json
/// [Body]:
///     query:
///         query Characters($page: Int) {
///           result: characters(page: $page) {
///             ...
///           }
///         }
///     variables:
///         {
///           "page" : 1
///         }
///
/// ♦️ 14:20:37.577 > [Done] API Request: [POST] https://rickandmortyapi.com/graphql
/// [Response]: Success ✅
/// Status Code: 200
/// [Headers]:
///     Content-Type: application/json; charset=utf-8
/// Response Length: 4321
/// Response body: {"data":{...}}
/// ```
///
/// Headers are sorted by name so the same response always prints the same way;
/// a dictionary would otherwise reorder them between runs.
///
/// The request body is unpacked because the interesting part of a GraphQL
/// request — the document — travels as one JSON string, newlines escaped, and
/// is unreadable in that form. The response body is printed as the wire
/// carried it: it is what the decoder saw, and a formatter reflowing it would
/// hide exactly the kind of mismatch the log is there to reveal.
public struct APILogFormatter: Sendable {
    private let timeFormatter: DateFormatter

    public init(timeZone: TimeZone = .current) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss.SSS"
        timeFormatter = formatter
    }

    public func string(for event: APILogEvent) -> String {
        switch event {
        case .request(let record):
            return string(for: record)
        case .response(let record):
            return string(for: record)
        }
    }

    public func string(for record: APIRequestRecord) -> String {
        var lines = [
            "♦️ \(time(record.timestamp)) > [PENDING] API Request: [\(record.method)] \(record.url.absoluteString)",
            "[Method]: \(record.method)",
        ]
        lines.append(contentsOf: headerLines(record.headers))
        lines.append(contentsOf: requestBodyLines(record.body))
        return lines.joined(separator: "\n")
    }

    public func string(for record: APIResponseRecord) -> String {
        var lines = [
            "♦️ \(time(record.timestamp)) > [Done] API Request: [\(record.method)] \(record.url.absoluteString)",
        ]
        switch record.outcome {
        case .success(let statusCode):
            lines.append("[Response]: Success ✅")
            lines.append("Status Code: \(statusCode)")
        case .failure(let statusCode):
            lines.append("[Response]: Failure ❌")
            lines.append("Status Code: \(statusCode)")
        case .transportError(let description):
            lines.append("[Response]: Failure ❌")
            lines.append("Error: \(description)")
        }
        lines.append(contentsOf: headerLines(record.headers))
        lines.append("Response Length: \(record.length)")
        lines.append("Response body: \(text(record.body))")
        return lines.joined(separator: "\n")
    }

    private func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private func headerLines(_ headers: [String: String]) -> [String] {
        ["[Headers]: "] + headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "    \($0.key): \($0.value)" }
    }

    /// A GraphQL request body as `query:` with the document verbatim and
    /// `variables:` as indented JSON. Anything else is printed raw, on the
    /// `[Body]:` line, so a body that is not what the client sends still shows.
    private func requestBodyLines(_ body: Data?) -> [String] {
        guard let body,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let query = object["query"] as? String else {
            return ["[Body]: \(text(body))"]
        }

        var lines = ["[Body]: ", "    query: "]
        lines.append(contentsOf: indented(query, by: 8))
        if let variables = object["variables"] {
            lines.append("    variables: ")
            lines.append(contentsOf: indented(prettyJSON(variables), by: 8))
        }
        return lines
    }

    private func prettyJSON(_ value: Any) -> String {
        guard JSONSerialization.isValidJSONObject(value),
              let data = try? JSONSerialization.data(
                withJSONObject: value, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
              ) else {
            return "\(value)"
        }
        return String(decoding: data, as: UTF8.self)
    }

    private func indented(_ text: String, by spaces: Int) -> [String] {
        let indent = String(repeating: " ", count: spaces)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { indent + $0 }
    }

    /// The body as the wire carried it. Bytes that are not UTF-8 are described
    /// rather than dumped, so a stray binary response cannot flood the console.
    private func text(_ body: Data?) -> String {
        guard let body, !body.isEmpty else { return "<empty>" }
        return String(data: body, encoding: .utf8) ?? "<\(body.count) bytes of non-UTF-8 data>"
    }
}
