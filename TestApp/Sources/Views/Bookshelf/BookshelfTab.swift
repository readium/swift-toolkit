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
    
    @EnvironmentStateObject private var viewModel: BookshelfTabViewModel
    @State private var showingSheet = false
    
    init() {
        _viewModel = EnvironmentStateObject {
            BookshelfTabViewModel(
                db: $0.db)
        }
    }
    
    var body: some View {
        VStack {
            NavigationView {
                // TODO figure out what the best column layout is for phones and tablets
                if let books = viewModel.books {
                    let columns: [GridItem] = Array(repeating: .init(.adaptive(minimum: 170)), count: 2)
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(books, id: \.self) { item in
                                BookCover(book: item)
                            }
                        }
                    }
                    .navigationTitle("Bookshelf")
                    .toolbar(content: toolbarContent)
                }
            }
            .sheet(isPresented: $showingSheet) {
                AddBookSheet(showingSheet: $showingSheet) { url in
                    // TODO validate the URL and import the book
                }
            }
        }
    }
}

extension BookshelfTab {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                showingSheet = true
            }
        }
    }
}

struct BookshelfTab_Previews: PreviewProvider {
    static var previews: some View {
        BookshelfTab()
    }
}
