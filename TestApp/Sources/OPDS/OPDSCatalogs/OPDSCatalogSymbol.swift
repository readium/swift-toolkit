//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

enum OPDSCatalogSymbol: String, CaseIterable, Identifiable {
    case book
    case bookFill = "book.fill"
    case booksVertical = "books.vertical"
    case booksVerticalFill = "books.vertical.fill"
    case bookmark
    case bookmarkFill = "bookmark.fill"
    case textBookClosed = "text.book.closed"
    case textBookClosedFill = "text.book.closed.fill"
    case bookCircle = "book.circle"
    case bookCircleFill = "book.circle.fill"

    var id: String { rawValue }
}
