//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Streamer
import UIKit

/// The Library module handles the presentation of the bookshelf, and the publications' management.
protocol LibraryModuleAPI {
    var delegate: LibraryModuleDelegate? { get }

    /// Root navigation controller containing the Library.
    /// Can be used to present the library to the user.
    var rootViewController: UINavigationController { get }

    /// Imports a new publication to the library, either from:
    /// - a local file URL
    /// - a remote URL which will be downloaded
    func importPublication(from url: URL, sender: UIViewController) async throws -> Book
}

protocol LibraryModuleDelegate: ModuleDelegate {
    /// Called when the user tap on a publication in the library.
    func libraryDidSelectPublication(_ publication: Publication, book: Book)
}

final class LibraryModule: LibraryModuleAPI {
    weak var delegate: LibraryModuleDelegate?

    private let library: LibraryService
    private let factory: LibraryFactory
    private var subscriptions = Set<AnyCancellable>()

    init(delegate: LibraryModuleDelegate?, books: BookRepository, httpClient: HTTPClient) {
        library = LibraryService(books: books, httpClient: httpClient)
        factory = LibraryFactory(libraryService: library)
        self.delegate = delegate
    }

    private(set) lazy var rootViewController: UINavigationController = .init(rootViewController: libraryViewController)

    private lazy var libraryViewController: LibraryViewController = {
        let library: LibraryViewController = factory.make()
        library.libraryDelegate = delegate
        return library
    }()

    func importPublication(from url: URL, sender: UIViewController) async throws -> Book {
        try await library.importPublication(from: url, sender: sender)
    }
}
