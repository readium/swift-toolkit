//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumAdapterGCDWebServer
import ReadiumNavigator
import ReadiumShared
import ReadiumStreamer
import UIKit

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
        Bookshelf(bookRepository: bookRepository, reader: reader(with:))
    }

    // Reader

    lazy var readerService: ReaderService = {
        var drmLibraryServices = [DRMLibraryService]()
        #if LCP
            drmLibraryServices.append(LCPLibraryService())
        #endif

        return ReaderService(
            bookmarks: BookmarkRepository(db: db),
            highlights: HighlightRepository(db: db),
            makeReaderVCFunc: makeReaderVCFunc,
            drmLibraryServices: drmLibraryServices,
            streamer: Streamer(
                contentProtections: drmLibraryServices.compactMap(\.contentProtection)
            ),
            httpClient: DefaultHTTPClient()
        )
    }()

    func reader(with book: Book) -> Reader {
        let viewModel = ReaderViewModel(book: book, readerService: readerService)
        return Reader(viewModel: viewModel)
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

extension Container {
    //TODO I don't know if this is the best spot for this code. I duplicated it in ReaderService where it might be better served.
    func makeReaderVCFunc(for publication: Publication, book: Book, delegate: NavigatorDelegate) -> ReaderViewControllerType {
        let locator = book.locator
        let httpServer = GCDHTTPServer.shared

        do {
            if publication.conforms(to: .pdf) {
                let navigator = try PDFNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? PDFNavigatorDelegate
                return navigator
            }

            if publication.conforms(to: .epub) || publication.readingOrder.allAreHTML {
                guard publication.metadata.identifier != nil else {
                    fatalError("ReaderError.epubNotValid")
                }

                let navigator = try EPUBNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? EPUBNavigatorDelegate
                return navigator
            }

            if publication.conforms(to: .divina) {
                let navigator = try CBZNavigatorViewController(publication: publication, initialLocation: locator, httpServer: httpServer)
                navigator.delegate = delegate as? CBZNavigatorDelegate
                return navigator
            }
        } catch {
            fatalError("Failed: \(error)")
        }
        return StubNavigatorViewController()
    }

    private class StubNavigatorViewController: UIViewController, Navigator {
        var publication: ReadiumShared.Publication

        var currentLocation: Locator?
    }
}
