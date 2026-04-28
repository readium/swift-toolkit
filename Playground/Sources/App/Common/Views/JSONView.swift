//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// A scrollable view that displays a JSON dictionary with syntax highlighting.
///
/// Serialization and colorization run on a detached background task to keep the UI
/// responsive for large manifests. A `ProgressView` is shown until the result is ready.
struct JSONView: View {
    /// The JSON dictionary to render.
    var json: [String: JSONValue]

    /// The colorized attributed text; `nil` while the background task is running.
    @State private var attributedText: AttributedString?

    /// Holds any serialization error to display in an alert.
    @State private var error: UserError?

    var body: some View {
        ScrollView {
            if let attributedText {
                Text(attributedText)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ProgressView()
            }
        }
        .alert(error: $error)
        .task {
            let json = json
            do {
                attributedText = try await Task.detached(priority: .userInitiated) {
                    try await colorizeJSON(json)
                }.value

            } catch {
                self.error = UserError(error)
            }
        }
    }

    /// Serializes `json` to a pretty-printed string and applies token-level syntax highlighting.
    ///
    /// Uses a greedy left-to-right regex pass with a `claimed` bitmap to ensure each
    /// character is colored by at most one pattern (keys take precedence over string values).
    ///
    /// Color scheme:
    /// - **Keys** (string before `:`): green + bold
    /// - **String values**: blue
    /// - **Numbers**: orange
    /// - **Booleans**: purple
    /// - **null**: grey
    @concurrent private func colorizeJSON(_ json: [String: JSONValue]) async throws -> AttributedString {
        let data = try JSONSerialization.data(
            withJSONObject: json.mapValues(\.any),
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )

        let jsonString = String(data: data, encoding: .utf8)!
        let length = (jsonString as NSString).length
        let fullRange = NSRange(location: 0, length: length)

        let attributed = NSMutableAttributedString(string: jsonString)
        var claimed = [Bool](repeating: false, count: length)

        for (regex, color) in await Self.patterns {
            for match in regex.matches(in: jsonString, range: fullRange) {
                let range = match.range
                let end = range.location + range.length
                guard !(range.location ..< end).contains(where: { claimed[$0] }) else { continue }
                for i in range.location ..< end {
                    claimed[i] = true
                }
                attributed.addAttribute(.foregroundColor, value: color, range: range)
            }
        }

        return try AttributedString(attributed, including: \.uiKit)
    }

    static let patterns: [(NSRegularExpression, UIColor)] = [
        (try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*"(?=\s*:)"#), .systemGreen),
        (try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#), .systemBlue),
        (try! NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#), .systemOrange),
        (try! NSRegularExpression(pattern: #"\b(?:true|false)\b"#), .systemPurple),
        (try! NSRegularExpression(pattern: #"\bnull\b"#), .systemGray),
    ]
}
