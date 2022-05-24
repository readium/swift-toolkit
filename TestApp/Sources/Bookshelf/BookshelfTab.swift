//
//  BookshelfTab.swift
//  TestApp
//
//  Created by Steven Zeck on 5/15/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import SwiftUI
import GRDBQuery

struct BookshelfTab: View {
    
    @Query(BookListRequest())
    var books: [Book]
    
    var body: some View {
        NavigationView {
            // TODO figure out what the best column layout is for phones and tablets
            let columns: [GridItem] = Array(repeating: .init(.adaptive(minimum: 170)), count: 2)
            let bookList = books
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(bookList, id: \.self) { item in
                        BookCover(book: item)
                    }
                }
            }
            .navigationTitle("Bookshelf")
            .toolbar(content: toolbarContent)
        }
    }
}

extension BookshelfTab {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                
            }
        }
    }
}

struct BookshelfTab_Previews: PreviewProvider {
    static var previews: some View {
        BookshelfTab()
    }
}
