//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct HTMLText: View {
    private var text: String
    @State private var attributedText: AttributedString?

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Group {
            if let attributedText {
                Text(attributedText)
            } else {
                Text(text)
            }
        }
        .task(id: text) {
            attributedText = await parseHTML(text)
        }
    }

    private func parseHTML(_ html: String) async -> AttributedString? {
        await Task.detached {
            try? AttributedString(
                NSAttributedString(
                    data: Data(html.utf8),
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue,
                    ],
                    documentAttributes: nil
                ),
                including: \.swiftUI
            )
        }.value
    }
}
