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
    var json: [String: Any]

    /// The colorized attributed text; `nil` while the background task is running.
    @State private var attributedText: AttributedString?

    /// Holds any serialization error to display in an alert.
    @State private var error: UserError?

    var body: some View {
        ScrollView {
            if let attributedText {
                Text(attributedText)
                    .font(.body.monospaced())
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
    @concurrent private func colorizeJSON(_ json: [String: Any]) async throws -> AttributedString {
        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )

        let jsonString = String(data: data, encoding: .utf8)!
        let length = (jsonString as NSString).length
        let fullRange = NSRange(location: 0, length: length)

        let attributed = NSMutableAttributedString(string: jsonString)
        var claimed = [Bool](repeating: false, count: length)

        let boldFont = UIFont.monospacedSystemFont(
            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
            weight: .bold
        )

        let patterns: [(NSRegularExpression, UIColor, bold: Bool)] = [
            (try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*"(?=\s*:)"#), .systemGreen, true),
            (try! NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#), .systemBlue, false),
            (try! NSRegularExpression(pattern: #"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?"#), .systemOrange, false),
            (try! NSRegularExpression(pattern: #"\b(?:true|false)\b"#), .systemPurple, false),
            (try! NSRegularExpression(pattern: #"\bnull\b"#), .systemGray, false),
        ]

        for (regex, color, bold) in patterns {
            for match in regex.matches(in: jsonString, range: fullRange) {
                let range = match.range
                let end = range.location + range.length
                guard !(range.location ..< end).contains(where: { claimed[$0] }) else { continue }
                for i in range.location ..< end {
                    claimed[i] = true
                }
                attributed.addAttribute(.foregroundColor, value: color, range: range)
                if bold {
                    attributed.addAttribute(.font, value: boldFont, range: range)
                }
            }
        }

        return try AttributedString(attributed, including: \.uiKit)
    }
}
