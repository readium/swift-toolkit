//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Streamer
import R2Navigator
import UIKit

typealias ReaderViewControllerType = UIViewController & Navigator

class ReaderDependencies {
    let books: BookRepository
    let bookmarks: BookmarkRepository
    let highlights: HighlightRepository
    let publicationServer: PublicationServer
    let makeReaderVCFunc: (Publication, Book) -> ReaderViewControllerType
    let drmLibraryServices: [DRMLibraryService]
    let streamer: Streamer
    let httpClient: HTTPClient
    
    init(books: BookRepository,
         bookmarks: BookmarkRepository,
         highlights: HighlightRepository,
         publicationServer: PublicationServer,
         makeReaderVCFunc: @escaping (Publication, Book) -> ReaderViewControllerType,
         drmLibraryServices: [DRMLibraryService],
         streamer: Streamer,
         httpClient: HTTPClient
    ) {
        self.books = books
        self.bookmarks = bookmarks
        self.highlights = highlights
        self.publicationServer = publicationServer
        self.makeReaderVCFunc = makeReaderVCFunc
        self.drmLibraryServices = drmLibraryServices
        self.streamer = streamer
        self.httpClient = httpClient
    }
}

class Container {
    
    private let db: Database
    
    /// Everything for Reader Module
    lazy var readerDependencies: ReaderDependencies = {
        var drmLibraryServices = [DRMLibraryService]()
        #if LCP
        drmLibraryServices.append(LCPLibraryService())
        #endif

        return ReaderDependencies(
            books: BookRepository(db: db),
            bookmarks: BookmarkRepository(db: db),
            highlights: HighlightRepository(db: db),
            publicationServer: PublicationServer()!,
            makeReaderVCFunc: createNavigatorVC,
            drmLibraryServices: drmLibraryServices,
            streamer: Streamer(
                contentProtections: drmLibraryServices.compactMap { $0.contentProtection }
            ),
            httpClient: DefaultHTTPClient()
        )
    }()
    
    init() throws {
        self.db = try Database(
            file: Paths.library.appendingPathComponent("database.db"),
            migrations: [InitialMigration()]
        )
    }
    
// MARK: - Bookshelf
    
    func bookshelf() -> Bookshelf {
        Bookshelf(
            readerDependencies: readerDependencies,
            bookOpener: BookOpener(readerDependencies: readerDependencies)
        )
    }
    
// MARK: - Catalogs
    
    private lazy var catalogRepository = CatalogRepository(db: db)
    
    func catalogs() -> CatalogList {
        CatalogList(
            catalogRepository: catalogRepository,
            catalogFeed: catalogFeed(with:)
        )
    }
    
    func catalogFeed(with catalog: Catalog) -> CatalogFeed {
        CatalogFeed(catalog: catalog,
                      catalogFeed: catalogFeed(with:),
                      publicationDetail: publicationDetail(with:)
        )
    }
    
    func publicationDetail(with publication: Publication) -> PublicationDetail {
        PublicationDetail(publication: publication)
    }
    
// MARK: - About
    
    func about() -> About {
        About()
    }
    
// MARK: - Reader
    
    func createNavigatorVC(for publication: Publication, book: Book) -> ReaderViewControllerType {
        
        let locator = book.locator
        let resourcesServer = readerDependencies.publicationServer
        
        if publication.conforms(to: .pdf) {
            let navigator = PDFNavigatorViewController(publication: publication, initialLocation: locator)
            //navigator.delegate = self
            return navigator
        }
        
        if publication.conforms(to: .epub) || publication.readingOrder.allAreHTML {
            // this will be epub
            guard publication.metadata.identifier != nil else {
                //throw ReaderError.epubNotValid
                fatalError("ReaderError.epubNotValid")
            }
            
            let navigator = EPUBNavigatorViewController(publication: publication, initialLocation: locator, resourcesServer: resourcesServer)
//            self.navigator = navigator 
            return navigator
        }
        
        if publication.conforms(to: .divina) {
            let navigator = CBZNavigatorViewController(publication: publication, initialLocation: locator)
            //navigator.delegate = self
            return navigator
        }
        
        return StubNavigatorViewController()
    }
    
    /// To avoid optional result in "createNavigatorVC"
    private class StubNavigatorViewController: UIViewController, Navigator {
        var currentLocation: Locator?
    }
}


