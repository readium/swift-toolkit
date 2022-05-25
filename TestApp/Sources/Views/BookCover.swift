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
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 220)
            Text(book.title)
            Text(book.authors ?? "")
        }
    }
}

extension BookCover {
    var image: Image {
        if let coverURL = book.cover,
           let data = try? Data(contentsOf: coverURL),
           let image = UIImage(data: data) {
            return Image(uiImage: image)
        } else {
            return Image("defaultCover")
        }
    }
}

struct BookCover_Previews: PreviewProvider {
    static var previews: some View {
        let book = Book(title: "Test Title", authors: "Test Author", type: "application/epub+zip", path: "/test/path/")
        BookCover(book: book)
    }
}
