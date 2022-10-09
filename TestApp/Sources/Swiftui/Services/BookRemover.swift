//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Combine

actor BookRemover {
    private let readerDependencies: ReaderDependencies
    private var subscriptions = Set<AnyCancellable>()
    
    init(readerDependencies: ReaderDependencies) {
        self.readerDependencies = readerDependencies
    }
    
    func remove(_ book: Book) async -> Result<Void, LibraryError> {
        // FIXME: ? // this line was before SwiftUI
        readerDependencies.publicationServer.remove(at: book.path)
        
        let urlResult = await book.url()
        do {
            try await removeBookRecord(book)
            try await removeBookFile(at: urlResult.get())
        } catch let error {
            if let libraryError = error as? LibraryError {
                return .failure(libraryError)
            }
        }
        
        return .success(())
    }
    
    /// throws - LibraryError
    private func removeBookRecord(_ book: Book) async throws {
        guard let id = book.id else {
            throw LibraryError.bookDeletionFailed(nil)
        }
        
        return try await withCheckedThrowingContinuation({ continuation in
            readerDependencies.books.remove(id)
                .sink { completion in
                    if case .failure(let error) = completion {
                        continuation.resume(
                            throwing: LibraryError.bookDeletionFailed(error)
                        )
                    }
                } receiveValue: { _ in
                    continuation.resume(returning: ())
                }
                .store(in: &subscriptions)
        })
    }
    
    /// throws - LibraryError
    private func removeBookFile(at url: URL) async throws {
        if Paths.documents.isParentOf(url) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                throw LibraryError.bookDeletionFailed(error)
            }
        }
    }
}
