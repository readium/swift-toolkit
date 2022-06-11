//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import GRDB
import Combine
import Foundation

final class BookshelfViewModel: ObservableObject {
    
    @Published var books: [Book]?
    private var bookRepository: BookRepository
    
    init(bookRepository: BookRepository) {
        self.bookRepository =  bookRepository
    }
}
