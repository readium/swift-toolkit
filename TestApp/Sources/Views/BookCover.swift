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
        VStack {
            let width: CGFloat = 150
            cover
                .frame(width: width, height: 220, alignment: .bottom)
            labels
                .frame(width: width, alignment: .topLeading)
        }
    }
    
    @ViewBuilder
    private var cover: some View {
        if (url != nil) {
            AsyncImage(
                url: url,
                content: { $0
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .shadow(radius: 2)
                },
                placeholder: {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            )
        } else {
            Image(systemName: "book.closed")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    @ViewBuilder
    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            
            // Hack to reserve space for two lines of text.
            // See https://sarunw.com/posts/how-to-force-two-lines-of-text-in-swiftui/
            Text((authors ?? "") + "\n")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct BookCover_Previews: PreviewProvider {
    static var previews: some View {
        let book = Book(title: "Test Title", authors: "Test Author", type: "application/epub+zip", path: "/test/path/")
        BookCover(title: book.title, authors: book.authors)
    }
}
