//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct BookCover: View {
    var title: String
    var authors: String?
    var url: URL?
    var action: () -> Void = {}
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if (url != nil) {
                AsyncImage(
                    url: url,
                    content: { $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 220)
                    },
                    placeholder: { ProgressView() }
                )
            } else {
                Image(systemName: "book.closed")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 220)
            }
            Text(title)
            Text(authors ?? "")
        }.frame(maxWidth: 150)
    }
}

struct BookCover_Previews: PreviewProvider {
    static var previews: some View {
        let book = Book(title: "Test Title", authors: "Test Author", type: "application/epub+zip", path: "/test/path/")
        BookCover(title: book.title, authors: book.authors)
    }
}
