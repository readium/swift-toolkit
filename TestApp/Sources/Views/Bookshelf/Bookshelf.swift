//
//  Bookshelf.swift
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

struct Bookshelf: View {
    
    @ObservedObject var viewModel: BookshelfViewModel
    @State private var showingSheet = false
    
    var body: some View {
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
            .navigationViewStyle(.stack)
            .sheet(isPresented: $showingSheet) {
                AddBookSheet(showingSheet: $showingSheet) { url in
                    // TODO validate the URL and import the book
                }
            }
    }
}

extension Bookshelf {
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            AddButton {
                showingSheet = true
            }
        }
    }
}

