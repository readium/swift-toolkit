//
//  BookshelfViewModel.swift
//  TestApp
//
//  Created by Steven Zeck on 5/25/22.
//
//  Copyright 2022 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import GRDB
import Combine
import Foundation

final class BookshelfViewModel: ObservableObject {
    
    @Published var books: [Book]?
    private var bookRepository: BookRepository
    
    init(bookRepository: BookRepository) {
        self.bookRepository =  bookRepository
//        self.db = db
//        ValueObservation
//            .tracking(Book.order(Book.Columns.created).fetchAll)
//            .publisher(in: db.databaseReader, scheduling: .immediate)
//            .assertNoFailure()
//            .assign(to: &$books)
    }
}
