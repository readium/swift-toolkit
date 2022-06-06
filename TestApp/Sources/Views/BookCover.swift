//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct BookCover: View {
    var book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let url = book.cover {
                AsyncImage(
                    url: url,
                    content: { $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                    },
                    placeholder: { ProgressView() }
                )
            } else {
                Image(systemName: "book.closed")
            }
            Text(book.title)
            Text(book.authors ?? "")
        }
    }
}

struct BookCover_Previews: PreviewProvider {
    static var previews: some View {
        let book = Book(title: "Test Title", authors: "Test Author", type: "application/epub+zip", path: "/test/path/")
        BookCover(book: book)
    }
}
