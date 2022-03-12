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
    
    @ObservedObject var highlightsModel: HighlightsViewModel
    
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
        
        highlightsModel = HighlightsViewModel(bookId: bookId, highlightRepository: highlightRepository)
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
                List(highlightsModel.highlights, id: \.self) { highlight in
                    HighlightCellView(highlight: highlight)
                }
                //.overlay(StatusOverlay(model: model))
                .onAppear { self.highlightsModel.loadIfNeeded() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// Pattern used: https://stackoverflow.com/a/61858358/2567725
class HighlightsViewModel: ObservableObject {
    private let bookId: Book.Id
    private let highlightRepository: HighlightRepository
    
    init(bookId: Book.Id, highlightRepository: HighlightRepository) {
        self.bookId = bookId
        self.highlightRepository = highlightRepository
    }
    
    @Published var highlights = [Highlight]()
    @Published var state = State.ready

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    var dataTask: AnyPublisher<[Highlight], Error> {
        self.highlightRepository.all(for: bookId)
    }

    func load() {
        assert(Thread.isMainThread)
        self.state = .loading(self.dataTask.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.highlights = value
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = self.state else { return }
        self.load()
    }
}
