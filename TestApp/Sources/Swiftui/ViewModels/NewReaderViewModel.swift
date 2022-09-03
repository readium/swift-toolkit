//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import R2Shared
import R2Navigator
import SwiftUI
import WebKit

/// As we are reading, the state of the reader changes. All that changes are published here, and "NewReaderView" updates its UI.
class NewReaderViewModel: ObservableObject {
    let book: Book
    let publication: Publication
    let readerDependencies: ReaderDependencies
    
    @Published var positionLabelText: String = ""
    @Published var navigator: Navigator!
    
    private var subscriptions = Set<AnyCancellable>()
    private var bookId: Book.Id {
        book.id!
    }
    
    init(book: Book, publication: Publication, readerDependencies: ReaderDependencies) {
        self.book = book
        self.publication = publication
        self.readerDependencies = readerDependencies
    }
    
    func makeReaderVCFunc() -> UIViewController {
        let result = readerDependencies.makeReaderVCFunc(publication, book)
        self.navigator = result
        // TODO: become a delegate of a specific Format implementation
        return result
    }
}

//MARK: - Helpers
extension NewReaderViewModel: NavigatorDelegate {
    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {
        
    }
    
    func navigator(_ navigator: Navigator, locationDidChange locator: Locator) {
        positionLabelText = {
            if let position = locator.locations.position {
                return "\(position) / \(publication.positions.count)"
            } else if let progression = locator.locations.totalProgression {
                return "\(progression)%"
            } else {
                return ""
            }
        }()
    }
}
