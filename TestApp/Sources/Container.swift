//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

class Container {
    private let db: Database

    init() throws {
        db = try Database(
            file: Paths.library.appendingPath("database.db", isDirectory: false).url,
            migrations: [InitialMigration()]
        )
    }

    // Bookshelf

    private lazy var bookRepository = BookRepository(db: db)

    func bookshelf() -> Bookshelf {
        Bookshelf(bookRepository: bookRepository)
    }

    // Catalogs

    private lazy var catalogRepository = CatalogRepository(db: db)

    func catalogs() -> CatalogList {
        CatalogList(
            catalogRepository: catalogRepository,
            catalogFeed: catalogFeed(with:),
            publicationDetail: publicationDetail(with:)
        )
    }

    func catalogFeed(with catalog: Catalog) -> CatalogFeed {
        CatalogFeed(catalog: catalog)
    }

    func publicationDetail(with opdsPublication: OPDSPublication) -> PublicationDetail {
        PublicationDetail(opdsPublication: opdsPublication)
    }

    // About

    func about() -> About {
        About()
    }
}
