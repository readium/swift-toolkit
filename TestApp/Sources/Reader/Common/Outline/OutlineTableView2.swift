//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine
import R2Shared

struct OutlineTableView2: View {
    
    var publication: Publication!
    var bookId: Book.Id!
    var bookmarkRepository: BookmarkRepository!
    var highlightRepository: HighlightRepository!
    
    // Outlines (list of links) to display for each section.
    private var outlines: [Section: [(level: Int, link: R2Shared.Link)]] = [:]
    private var bookmarks: [Bookmark] = []
    @State var highlights: [Highlight] = []
    
    private var subscriptions = Set<AnyCancellable>()
    
    private enum Section: Int {
        case tableOfContents = 0, bookmarks, pageList, landmarks, highlights
    }
    @State private var selectedSection: Section = .tableOfContents
    
    init(publication: Publication, bookId: Book.Id, bookmarkRepository: BookmarkRepository, highlightRepository: HighlightRepository) {
     
        func flatten(_ links: [R2Shared.Link], level: Int = 0) -> [(level: Int, link: R2Shared.Link)] {
            return links.flatMap { [(level, $0)] + flatten($0.children, level: level + 1) }
        }
        
        outlines = [
            .tableOfContents: flatten(publication.tableOfContents),
            .landmarks: flatten(publication.landmarks),
            .pageList: flatten(publication.pageList)
        ]
        
        bookmarkRepository.all(for: bookId)
            .assertNoFailure()
            .sink { bookmarks in
                // Escaping closure captures mutating 'self' parameter
                // self.bookmarks = bookmarks
            }
            .store(in: &subscriptions)
        
        highlightRepository.all(for: bookId)
            .assertNoFailure()
            .sink { [self] highlights in
                // Escaping closure captures mutating 'self' parameter
                 self.highlights = highlights
            }
            .store(in: &subscriptions)
    }
    
    var body: some View {
        VStack {
            Picker("Favorite Color", selection: $selectedSection, content: {
                Text("Contents").tag(Section.tableOfContents)
                Text("Bookmarks").tag(Section.bookmarks)
                Text("Pagelist").tag(Section.pageList)
                Text("Landmarks").tag(Section.landmarks)
                Text("Highlights").tag(Section.highlights)
            })
            .pickerStyle(SegmentedPickerStyle())
            
            switch selectedSection {
            case .tableOfContents:
                EmptyView()
            case .bookmarks:
                EmptyView()
            case .pageList:
                EmptyView()
            case .landmarks:
                EmptyView()
            case .highlights:
                List(highlights, id: \.self) { highlight in
                    HighlightCellView(highlight: highlight)
                }
            }
        }
    }
}
