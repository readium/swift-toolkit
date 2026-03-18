//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

/// A SwiftUI `Text` view that renders an HTML string as rich attributed text.
struct HTMLText: View {
    /// The raw HTML string to render.
    private var text: String

    private enum ParsingResult {
        case parsing
        case parsed(AttributedString)
        case failure(Error)
    }

    @State private var state: ParsingResult = .parsing

    /// Creates an `HTMLText` view for the given HTML string.
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Group {
            switch state {
            case .parsing:
                ProgressView()
            case let .parsed(text):
                Text(text)
            case .failure:
                // Show the raw string as a fallback.
                Text(text)
            }
        }
        .task(id: text) {
            state = await parseHTML(text)
        }
    }

    /// Converts an HTML string into an `AttributedString` on a background
    /// thread.
    ///
    /// Returns `nil` if parsing fails (e.g. malformed HTML), in which case the
    /// raw text will be used as fallback.
    private func parseHTML(_ html: String) async -> ParsingResult {
        await Task.detached {
            do {
                return try .parsed(AttributedString(
                    NSAttributedString(
                        data: Data(html.utf8),
                        options: [
                            .documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue,
                        ],
                        documentAttributes: nil
                    ),
                    including: \.swiftUI
                ))
            } catch {
                return .failure(error)
            }
        }.value
    }
}
