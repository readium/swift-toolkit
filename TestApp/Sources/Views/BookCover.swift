//
//  Book.swift
//  TestApp
//
//  Created by Steven Zeck on 5/19/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
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
