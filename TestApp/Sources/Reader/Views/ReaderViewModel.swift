//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumNavigator
import ReadiumShared
import WebKit

class ReaderViewModel: ObservableObject {
    let book: Book
    // TODO: do we need publication in the VM?
    let publication: Publication?
    let readerService: ReaderService

    @Published var positionLabelText: String = ""
    @Published var navigator: Navigator!

    private var bookId: Book.Id {
        book.id!
    }

    init(book: Book, readerService: ReaderService) {
        self.book = book
        self.readerService = readerService
    }

    func makeReaderVCFunc() -> UIViewController {
        // Where best to get the publication from the book via openBook, which is async. Here?
        let result = readerService.makeReaderVCFunc(publication, book, self)
        navigator = result
        // TODO: become a delegate of a specific Format implementation
        return result
    }
}

extension ReaderViewModel: PDFNavigatorDelegate, EPUBNavigatorDelegate, CBZNavigatorDelegate {}

extension ReaderViewModel: NavigatorDelegate {
    func navigator(_ navigator: any ReadiumNavigator.Navigator, didFailToLoadResourceAt href: ReadiumShared.RelativeURL, withError error: ReadiumShared.ResourceError) {}

    func navigator(_ navigator: Navigator, presentError error: NavigatorError) {}

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

extension ReaderViewModel: VisualNavigatorDelegate {
    func navigator(_ navigator: VisualNavigator, didTapAt point: CGPoint) {
        // clear a current search highlight
        if let decorator = self.navigator as? DecorableNavigator {
            decorator.apply(decorations: [], in: "search")
        }
    }
}
