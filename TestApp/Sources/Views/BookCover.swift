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
                .frame(width: width, height: 60, alignment: .topLeading)
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
                .lineLimit(2)
            // If both the title and authors are too large, makes sure that
            // the title will take the priority to expand.
                .layoutPriority(1)
            
            Text(authors ?? "")
                .font(.subheadline)
                .lineLimit(2)
        }
        // Scales down the fonts.
//        .dynamicTypeSize(.small)
    }
}

struct BookCover_Previews: PreviewProvider {
    static var previews: some View {
        let book = Book(title: "Test Title", authors: "Test Author", type: "application/epub+zip", path: "/test/path/")
        BookCover(title: book.title, authors: book.authors)
    }
}
