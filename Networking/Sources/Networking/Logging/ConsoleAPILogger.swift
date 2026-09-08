import Foundation
import os

/// Writes every event to the unified logging system (`os.Logger`), which Xcode shows in its
/// console. `os.Logger`, not `print`, so a multi-line log is one entry a console filter matches
/// wholesale rather than just its first line. Logged as public: the sink is debug-only, and the
/// content already traveled on the wire.
public struct ConsoleAPILogger: APILogSinkContract {
    private let formatter: APILogFormatter
    private let logger: Logger

    /// - Parameters:
    ///   - subsystem: typically the app's bundle identifier, for filtering in Console.app.
    ///   - category: shown as a column in Xcode.
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

/// Turns a log event into the text the console shows. Headers are sorted by name for deterministic
/// output. Request bodies are unpacked since a GraphQL document travels as one escaped JSON string;
/// response bodies print exactly as the wire sent them, so a decoding mismatch stays visible.
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
            "♦️ \(time(record.timestamp)) > [PENDING] \(header(record.kind)): [\(record.method)] \(record.url.absoluteString)",
            "[Method]: \(record.method)"
        ]
        lines.append(contentsOf: headerLines(record.headers))
        lines.append(contentsOf: requestBodyLines(record.body))
        return lines.joined(separator: "\n")
    }

    public func string(for record: APIResponseRecord) -> String {
        var lines = [
            "♦️ \(time(record.timestamp)) > [Done] \(header(record.kind)): [\(record.method)] \(record.url.absoluteString)"
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

    /// On the header line, not a separate field, because that's what a console filter matches on.
    private func header(_ kind: APILogKind) -> String {
        switch kind {
        case .api:
            return "API Request"
        case .image:
            return "Image Request"
        }
    }

    private func headerLines(_ headers: [String: String]) -> [String] {
        ["[Headers]: "] + headers
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "    \($0.key): \($0.value)" }
    }

    /// GraphQL bodies print the document verbatim and variables as indented JSON; anything else
    /// is printed raw on the `[Body]:` line.
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

    /// Non-UTF-8 bytes are described, not dumped, so a binary response can't flood the console.
    private func text(_ body: Data?) -> String {
        guard let body, !body.isEmpty else { return "<empty>" }
        return String(data: body, encoding: .utf8) ?? "<\(body.count) bytes of non-UTF-8 data>"
    }
}
