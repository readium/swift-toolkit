//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

class Container {
    
    private let db: Database
    
    init() throws {
        self.db = try Database(file: Paths.library.appendingPathComponent("database.db"))
    }
    
    // Bookshelf
    
    private lazy var books = BookRepository(db: db)
    
    func bookshelf() -> Bookshelf {
        Bookshelf(viewModel: BookshelfViewModel(db: db))
    }
    
    // Catalogs
    
    func catalogs() -> Catalogs {
        Catalogs(
            viewModel: CatalogsViewModel(db: db),
            catalogDetail: catalogDetail(with:)
        )
    }
    
    func catalogDetail(with catalog: Catalog) -> CatalogDetail {
        CatalogDetail(viewModel: CatalogDetailViewModel(catalog: catalog))
    }
    
    // About
    
    func about() -> About {
        About()
    }
}
