//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct BookmarkCellView: View {
    static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    let bookmark: Bookmark
    var body: some View {
        HStack {
            VStack {
                Text(bookmark.locator.title ?? "")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                Text(bookmark.positionText ?? "")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Text(BookmarkCellView.dateFormatter.string(from: bookmark.created))
                .font(.footnote)
                .frame(maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .padding()
    }
}

extension Bookmark {
    var positionText: String? {
        if let position = locator.locations.position {
            return String(format: NSLocalizedString("reader_outline_position_label", comment: "Outline bookmark label when the position is available"), position)
        } else if let progression = locator.locations.progression {
            return String(format: NSLocalizedString("reader_outline_progression_label", comment: "Outline bookmark label when the progression is available"), progression * 100)
        } else {
            return nil
        }
    }
}
